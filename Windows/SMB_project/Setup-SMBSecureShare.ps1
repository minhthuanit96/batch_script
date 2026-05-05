#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Setup SMB Secure Share with restricted user account on Windows.
.DESCRIPTION
    This script performs the following tasks:
    1. Creates SMBUsers group and SMBUser with a strong password
    2. Disables SMBv1 and ensures SMBv2/v3 are enabled
    3. Checks and displays SMB signing policies status
    4. Creates a "scan" folder and shares it via SMB with proper permissions
    5. Creates a desktop shortcut to the shared folder
    6. Prevents SMBUser from logging in locally or via RDP using Local Security Policy

    All operations use official Microsoft PowerShell cmdlets.
    No registry hacks are used for user restrictions.
.EXAMPLE
    PS> .\Setup-SMBSecureShare.ps1
    Runs the complete SMB secure share setup.
.NOTES
    Author: Thuan Nguyen
    Date: 2026-05-05
    Version: 1.0.1
    Requires: Windows 10/11 or Windows Server 2016+, Administrator privileges
    References:
        - https://docs.microsoft.com/en-us/windows-server/storage/file-server/smb-configuration-options
        - https://docs.microsoft.com/en-us/powershell/module/smbshare/new-smbshare
        - https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/deny-logon-locally
#>

[CmdletBinding()]
param ()

$ErrorActionPreference = 'Stop'

# ============================================================================
# Configuration
# ============================================================================

function Import-EnvVariables {
    param ([string]$EnvFilePath)
    $envVars = @{}
    if (Test-Path $EnvFilePath) {
        Get-Content $EnvFilePath | ForEach-Object {
            $line = $_.Trim()
            if ($line -match "^([^#=]+)=(.*)$") {
                $envVars[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
    }
    return $envVars
}

$envFilePath = Join-Path -Path $PSScriptRoot -ChildPath "configure.env"
if (-not (Test-Path $envFilePath)) {
    Write-Host "[ERROR]   " -ForegroundColor Red -NoNewline
    Write-Host "Missing configuration file. Please copy 'configure.env.example' to 'configure.env' and fill in your details."
    exit 1
}

$envVariables = Import-EnvVariables -EnvFilePath $envFilePath

$SMBGroupName = if ($envVariables.SMB_GROUP_NAME) { $envVariables.SMB_GROUP_NAME } else { "SMBUsers" }
$SMBUserName = if ($envVariables.SMB_USER_NAME) { $envVariables.SMB_USER_NAME } else { "SMBUser" }
$SMBPassword = $envVariables.SMB_PASSWORD
$ShareName = if ($envVariables.SMB_SHARE_NAME) { $envVariables.SMB_SHARE_NAME } else { "scan" }

if (-not $SMBPassword) {
    Write-Host "[ERROR]   " -ForegroundColor Red -NoNewline
    Write-Host "SMB_PASSWORD must be specified in configure.env"
    exit 1
}

if ($envVariables.SMB_SHARE_PATH) {
    $ScanFolderPath = $envVariables.SMB_SHARE_PATH
}
else {
    $ScanFolderPath = Join-Path -Path "$env:USERPROFILE" -ChildPath $ShareName
}

$ComputerName = $env:COMPUTERNAME
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path -Path $DesktopPath -ChildPath "$ShareName (SMB Share).lnk"
$ShareUNCPath = "\\$ComputerName\$ShareName"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Step {
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )
    $colors = @{
        Info    = "Cyan"
        Success = "Green"
        Warning = "Yellow"
        Error   = "Red"
    }
    $prefix = @{
        Info    = "[INFO]   "
        Success = "[OK]     "
        Warning = "[WARN]   "
        Error   = "[ERROR]  "
    }
    Write-Host "$($prefix[$Type])" -ForegroundColor $colors[$Type] -NoNewline
    Write-Host $Message
}

function Write-SectionHeader {
    param (
        [Parameter(Mandatory)]
        [string]$Title
    )
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor DarkGray
    Write-Host "  $Title" -ForegroundColor White
    Write-Host ("=" * 70) -ForegroundColor DarkGray
}

# ============================================================================
# STEP 1: Create SMB Group and User
# ============================================================================

function Initialize-SMBGroupAndUser {
    Write-SectionHeader "STEP 1: Create SMB Group and User"

    # --- Create SMBUsers group ---
    $group = Get-LocalGroup -Name $SMBGroupName -ErrorAction SilentlyContinue
    if ($null -eq $group) {
        try {
            New-LocalGroup -Name $SMBGroupName -Description "Group for SMB file share access only"
            Write-Step "Created group '$SMBGroupName'" -Type Success
        }
        catch {
            Write-Step "Failed to create group '$SMBGroupName': $_" -Type Error
            throw
        }
    }
    else {
        Write-Step "Group '$SMBGroupName' already exists -- skipping" -Type Info
    }

    # --- Create SMBUser ---
    $user = Get-LocalUser -Name $SMBUserName -ErrorAction SilentlyContinue
    if ($null -eq $user) {
        try {
            $securePassword = ConvertTo-SecureString -String $SMBPassword -AsPlainText -Force
            New-LocalUser -Name $SMBUserName `
                -Password $securePassword `
                -FullName "SMB Share User" `
                -Description "Restricted SMB user. No login." `
                -PasswordNeverExpires `
                -UserMayNotChangePassword `
                -AccountNeverExpires
            Write-Step "Created user '$SMBUserName' with strong password" -Type Success
        }
        catch {
            Write-Step "Failed to create user '$SMBUserName': $_" -Type Error
            throw
        }
    }
    else {
        Write-Step "User '$SMBUserName' already exists -- skipping creation" -Type Info
    }

    # --- Add SMBUser to SMBUsers group ---
    $members = Get-LocalGroupMember -Group $SMBGroupName -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*\$SMBUserName" }
    if ($null -eq $members) {
        try {
            Add-LocalGroupMember -Group $SMBGroupName -Member $SMBUserName
            Write-Step "Added '$SMBUserName' to group '$SMBGroupName'" -Type Success
        }
        catch {
            Write-Step "Failed to add '$SMBUserName' to '$SMBGroupName': $_" -Type Error
            throw
        }
    }
    else {
        Write-Step "'$SMBUserName' is already a member of '$SMBGroupName' -- skipping" -Type Info
    }

    # --- Remove SMBUser from Users group (restrict default access) ---
    try {
        $inUsersGroup = Get-LocalGroupMember -Group "Users" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*\$SMBUserName" }
        if ($null -ne $inUsersGroup) {
            Remove-LocalGroupMember -Group "Users" -Member $SMBUserName -ErrorAction SilentlyContinue
            Write-Step "Removed '$SMBUserName' from 'Users' group for restriction" -Type Success
        }
    }
    catch {
        Write-Step "Note: Could not remove '$SMBUserName' from 'Users' group: $_" -Type Warning
    }
}

# ============================================================================
# STEP 2: Disable SMBv1 and Ensure SMBv2/v3 are Enabled
# ============================================================================

function Set-SMBProtocolConfiguration {
    Write-SectionHeader "STEP 2: Configure SMB Protocol Versions"

    # --- Check and disable SMBv1 ---
    try {
        $smbConfig = Get-SmbServerConfiguration
        if ($smbConfig.EnableSMB1Protocol -eq $true) {
            Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
            Write-Step "SMBv1 has been DISABLED (was enabled)" -Type Success
        }
        else {
            Write-Step "SMBv1 is already disabled" -Type Success
        }
    }
    catch {
        Write-Step "Failed to configure SMBv1: $_" -Type Error
        throw
    }

    # --- Disable SMBv1 Windows Feature (if available) ---
    try {
        $smbFeature = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue
        if ($null -ne $smbFeature -and $smbFeature.State -eq "Enabled") {
            Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Write-Step "SMBv1 Windows feature has been disabled" -Type Success
        }
        else {
            Write-Step "SMBv1 Windows feature is already disabled or not present" -Type Info
        }
    }
    catch {
        Write-Step "Note: Could not check SMBv1 feature (may not apply to this OS edition): $_" -Type Warning
    }

    # --- Check and enable SMBv2/v3 ---
    try {
        $smbConfig = Get-SmbServerConfiguration
        if ($smbConfig.EnableSMB2Protocol -eq $false) {
            Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force
            Write-Step "SMBv2/v3 has been ENABLED (was disabled)" -Type Success
        }
        else {
            Write-Step "SMBv2/v3 is already enabled" -Type Success
        }
    }
    catch {
        Write-Step "Failed to configure SMBv2/v3: $_" -Type Error
        throw
    }

    # --- Display final SMB status ---
    Write-Host ""
    Write-Step "Current SMB Protocol Status:" -Type Info
    $finalConfig = Get-SmbServerConfiguration
    $smb1Color = if ($finalConfig.EnableSMB1Protocol) { "Red" } else { "Green" }
    $smb2Color = if ($finalConfig.EnableSMB2Protocol) { "Green" } else { "Red" }
    Write-Host "    SMBv1 Enabled : $($finalConfig.EnableSMB1Protocol)" -ForegroundColor $smb1Color
    Write-Host "    SMBv2 Enabled : $($finalConfig.EnableSMB2Protocol)" -ForegroundColor $smb2Color
}

# ============================================================================
# STEP 3: Check and Display SMB Signing Policies
# ============================================================================

function Show-SMBSigningPolicies {
    Write-SectionHeader "STEP 3: SMB Signing Policies Status"

    # --- Microsoft network client: Digitally sign communications (always) ---
    Write-Step "Checking SMB signing policies..." -Type Info
    Write-Host ""

    try {
        $clientSignPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
        $clientSign = Get-ItemProperty -Path $clientSignPath -Name "RequireSecuritySignature" -ErrorAction SilentlyContinue
        $clientSignValue = if ($null -ne $clientSign) { $clientSign.RequireSecuritySignature } else { 0 }
        $clientSignStatus = if ($clientSignValue -eq 1) { "Enabled" } else { "Disabled" }
        $clientSignColor = if ($clientSignValue -eq 1) { "Green" } else { "Yellow" }

        Write-Host "    Microsoft network client: Digitally sign communications (always)" -ForegroundColor White
        Write-Host "    Status : " -NoNewline
        Write-Host "$clientSignStatus" -ForegroundColor $clientSignColor
        Write-Host "    Registry: $clientSignPath\RequireSecuritySignature = $clientSignValue"
        Write-Host ""
    }
    catch {
        Write-Step "Failed to read client signing policy: $_" -Type Error
    }

    # --- Microsoft network server: Digitally sign communications (always) ---
    try {
        $serverSignPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
        $serverSign = Get-ItemProperty -Path $serverSignPath -Name "RequireSecuritySignature" -ErrorAction SilentlyContinue
        $serverSignValue = if ($null -ne $serverSign) { $serverSign.RequireSecuritySignature } else { 0 }
        $serverSignStatus = if ($serverSignValue -eq 1) { "Enabled" } else { "Disabled" }
        $serverSignColor = if ($serverSignValue -eq 1) { "Green" } else { "Yellow" }

        Write-Host "    Microsoft network server: Digitally sign communications (always)" -ForegroundColor White
        Write-Host "    Status : " -NoNewline
        Write-Host "$serverSignStatus" -ForegroundColor $serverSignColor
        Write-Host "    Registry: $serverSignPath\RequireSecuritySignature = $serverSignValue"
        Write-Host ""
    }
    catch {
        Write-Step "Failed to read server signing policy: $_" -Type Error
    }

    # --- Also check "if agreed" policies ---
    try {
        $clientEnableSign = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "EnableSecuritySignature" -ErrorAction SilentlyContinue
        $clientEnableValue = if ($null -ne $clientEnableSign) { $clientEnableSign.EnableSecuritySignature } else { 0 }
        $serverEnableSign = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "EnableSecuritySignature" -ErrorAction SilentlyContinue
        $serverEnableValue = if ($null -ne $serverEnableSign) { $serverEnableSign.EnableSecuritySignature } else { 0 }

        $clientIfStatus = if ($clientEnableValue -eq 1) { "Enabled" } else { "Disabled" }
        $serverIfStatus = if ($serverEnableValue -eq 1) { "Enabled" } else { "Disabled" }

        Write-Host "    Microsoft network client: Digitally sign communications (if server agrees)" -ForegroundColor White
        Write-Host "    Status : $clientIfStatus"
        Write-Host ""
        Write-Host "    Microsoft network server: Digitally sign communications (if client agrees)" -ForegroundColor White
        Write-Host "    Status : $serverIfStatus"
        Write-Host ""
    }
    catch {
        Write-Step "Failed to read optional signing policies: $_" -Type Warning
    }
}

# ============================================================================
# STEP 4: Create "scan" Folder and Share Over SMB
# ============================================================================

function New-SMBScanShare {
    Write-SectionHeader "STEP 4: Create 'scan' Folder and SMB Share"

    # --- Create the scan folder ---
    if (-not (Test-Path -Path $ScanFolderPath)) {
        try {
            New-Item -ItemType Directory -Path $ScanFolderPath -Force | Out-Null
            Write-Step "Created folder: $ScanFolderPath" -Type Success
        }
        catch {
            Write-Step "Failed to create folder '$ScanFolderPath': $_" -Type Error
            throw
        }
    }
    else {
        Write-Step "Folder already exists: $ScanFolderPath" -Type Info
    }

    # --- Set NTFS Permissions for SMBUser ---
    try {
        $acl = Get-Acl -Path $ScanFolderPath

        # Define the access rule: ReadAndExecute + Write (covers Read, List, Execute, Write)
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $SMBUserName,
            "ReadAndExecute, Write",
            "ContainerInherit, ObjectInherit",
            "None",
            "Allow"
        )

        $acl.SetAccessRule($accessRule)
        Set-Acl -Path $ScanFolderPath -AclObject $acl
        Write-Step "Set NTFS permissions for '$SMBUserName': ReadAndExecute, Write" -Type Success
    }
    catch {
        Write-Step "Failed to set NTFS permissions: $_" -Type Error
        throw
    }

    # --- Create or update SMB Share ---
    $existingShare = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
    if ($null -ne $existingShare) {
        try {
            # Remove existing share to recreate with correct settings
            Remove-SmbShare -Name $ShareName -Force
            Write-Step "Removed existing share '$ShareName' for reconfiguration" -Type Info
        }
        catch {
            Write-Step "Failed to remove existing share: $_" -Type Error
            throw
        }
    }

    try {
        New-SmbShare -Name $ShareName `
            -Path $ScanFolderPath `
            -Description "Scan folder - SMB secure share" `
            -FullAccess "Administrators" `
            -ChangeAccess $SMBUserName | Out-Null
        Write-Step "Created SMB share '$ShareName' -> $ScanFolderPath" -Type Success
        Write-Step "Share permissions: '$SMBUserName' = Change, 'Administrators' = Full" -Type Info
        Write-Step "UNC Path: $ShareUNCPath" -Type Info
    }
    catch {
        Write-Step "Failed to create SMB share: $_" -Type Error
        throw
    }
}

# ============================================================================
# STEP 5: Create Desktop Shortcut to Shared Folder
# ============================================================================

function New-ShareShortcut {
    Write-SectionHeader "STEP 5: Create Desktop Shortcut"

    try {
        $wshell = New-Object -ComObject WScript.Shell
        $shortcut = $wshell.CreateShortcut($ShortcutPath)
        $shortcut.TargetPath = $ScanFolderPath
        $shortcut.Description = "SMB Shared Scan Folder"
        $shortcut.WorkingDirectory = $ScanFolderPath
        $shortcut.Save()

        # Release COM object
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($wshell) | Out-Null

        Write-Step "Created shortcut on Desktop: $ShortcutPath" -Type Success
        Write-Step "Shortcut target: $ScanFolderPath" -Type Info
    }
    catch {
        Write-Step "Failed to create desktop shortcut: $_" -Type Error
        throw
    }
}

# ============================================================================
# STEP 6: Prevent SMBUser from Logging In (Local Security Policy)
# ============================================================================

function Deny-SMBUserLogon {
    Write-SectionHeader "STEP 6: Deny Logon Rights for SMBUser"

    Write-Step "Configuring Local Security Policy to deny logon for '$SMBUserName'..." -Type Info

    $tempCfgPath = Join-Path -Path $env:TEMP -ChildPath "secpol_export.cfg"
    $tempDbPath = Join-Path -Path $env:TEMP -ChildPath "secpol_import.sdb"

    try {
        # --- Export current security policy ---
        $exportResult = secedit /export /cfg $tempCfgPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Step "Failed to export security policy: $exportResult" -Type Error
            throw "secedit export failed"
        }
        Write-Step "Exported current security policy" -Type Info

        # --- Read the config file ---
        $configContent = Get-Content -Path $tempCfgPath -Raw

        # --- Process SeDenyInteractiveLogonRight (Deny logon locally) ---
        if ($configContent -match 'SeDenyInteractiveLogonRight\s*=\s*(.*)') {
            $currentValue = $matches[1].Trim()
            if ($currentValue -notlike "*$SMBUserName*") {
                $newValue = "$currentValue,$SMBUserName"
                $configContent = $configContent -replace 'SeDenyInteractiveLogonRight\s*=\s*.*', "SeDenyInteractiveLogonRight = $newValue"
                Write-Step "Added '$SMBUserName' to 'Deny logon locally' policy" -Type Success
            }
            else {
                Write-Step "'$SMBUserName' already in 'Deny logon locally' -- skipping" -Type Info
            }
        }
        else {
            # Policy line does not exist -- add it under [Privilege Rights]
            $configContent = $configContent -replace '(\[Privilege Rights\])', "`$1`r`nSeDenyInteractiveLogonRight = $SMBUserName"
            Write-Step "Created 'Deny logon locally' policy with '$SMBUserName'" -Type Success
        }

        # --- Process SeDenyRemoteInteractiveLogonRight (Deny logon through RDP) ---
        if ($configContent -match 'SeDenyRemoteInteractiveLogonRight\s*=\s*(.*)') {
            $currentValue = $matches[1].Trim()
            if ($currentValue -notlike "*$SMBUserName*") {
                $newValue = "$currentValue,$SMBUserName"
                $configContent = $configContent -replace 'SeDenyRemoteInteractiveLogonRight\s*=\s*.*', "SeDenyRemoteInteractiveLogonRight = $newValue"
                Write-Step "Added '$SMBUserName' to 'Deny logon through RDP' policy" -Type Success
            }
            else {
                Write-Step "'$SMBUserName' already in 'Deny logon through RDP' -- skipping" -Type Info
            }
        }
        else {
            $configContent = $configContent -replace '(\[Privilege Rights\])', "`$1`r`nSeDenyRemoteInteractiveLogonRight = $SMBUserName"
            Write-Step "Created 'Deny logon through RDP' policy with '$SMBUserName'" -Type Success
        }

        # --- Write modified config back ---
        Set-Content -Path $tempCfgPath -Value $configContent -Force

        # --- Apply the modified security policy ---
        $importResult = secedit /configure /db $tempDbPath /cfg $tempCfgPath /areas USER_RIGHTS 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Step "Failed to apply security policy: $importResult" -Type Error
            throw "secedit configure failed"
        }
        Write-Step "Applied Local Security Policy changes successfully" -Type Success

    }
    catch {
        Write-Step "Failed to configure logon restrictions: $_" -Type Error
        throw
    }
    finally {
        # --- Cleanup temp files ---
        Remove-Item -Path $tempCfgPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $tempDbPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $env:TEMP "secpol_import.sdb.jfm") -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $env:TEMP "secpol_import.sdb.log") -Force -ErrorAction SilentlyContinue
        Write-Step "Cleaned up temporary policy files" -Type Info
    }
}

# ============================================================================
# Main Execution
# ============================================================================

function Show-Banner {
    Write-Host ""
    Write-Host "  +====================================================================+" -ForegroundColor Cyan
    Write-Host "  |              SETUP SMB SECURE SHARE - v1.0.1                       |" -ForegroundColor Cyan
    Write-Host "  |              Author: Thuan Nguyen                                  |" -ForegroundColor Cyan
    Write-Host "  |              Windows SMB File Sharing Configuration                |" -ForegroundColor Cyan
    Write-Host "  +====================================================================+" -ForegroundColor Cyan
    Write-Host ""
}

try {
    Show-Banner

    # Execute all steps in sequence
    Initialize-SMBGroupAndUser
    Set-SMBProtocolConfiguration
    Show-SMBSigningPolicies
    New-SMBScanShare
    New-ShareShortcut
    Deny-SMBUserLogon

    # --- Final Summary ---
    Write-SectionHeader "SETUP COMPLETE"
    Write-Host ""
    Write-Step "All tasks completed successfully!" -Type Success
    Write-Host ""
    Write-Host "  Summary:" -ForegroundColor White
    Write-Host "    User          : $SMBUserName (in group '$SMBGroupName')" -ForegroundColor Gray
    Write-Host "    Password      : $SMBPassword" -ForegroundColor Gray
    Write-Host "    Shared Folder : $ScanFolderPath" -ForegroundColor Gray
    Write-Host "    Share Name    : $ShareName" -ForegroundColor Gray
    Write-Host "    UNC Path      : $ShareUNCPath" -ForegroundColor Gray
    Write-Host "    Shortcut      : $ShortcutPath" -ForegroundColor Gray
    Write-Host "    SMBv1         : Disabled" -ForegroundColor Green
    Write-Host "    SMBv2/v3      : Enabled" -ForegroundColor Green
    Write-Host "    User Logon    : Denied (local + RDP)" -ForegroundColor Green
    Write-Host ""
    Write-Step "The SMBUser can access \\$ComputerName\$ShareName but cannot log in to this machine." -Type Info
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Step "Script failed with error: $_" -Type Error
    Write-Step "Please check the error above and ensure you are running as Administrator." -Type Error
    exit 1
}
