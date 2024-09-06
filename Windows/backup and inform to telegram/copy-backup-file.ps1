   function Get-FileChecksum {
       param (
           [string]$filePath
       )
       $hasher = [System.Security.Cryptography.SHA256]::Create()
       $stream = [System.IO.File]::OpenRead($filePath)
       [byte[]]$hash = $hasher.ComputeHash($stream)
       $stream.Close()
       return [BitConverter]::ToString($hash) -replace '-', ''
   }
   function Verify-Checksum {
       param (
           [string]$file1,
           [string]$file2
       )
       $checksum1 = Get-FileChecksum -filePath $file1
       $checksum2 = Get-FileChecksum -filePath $file2
       return $checksum1 -eq $checksum2
   }
   function Send-TelegramMessage {
       param (
           [string]$botToken,
           [string]$chatID,
           [string]$message,
           [string]$messagethreadid
       )
       $url = "https://api.telegram.org/bot$($botToken)/sendMessage?chat_id=$($chatID)&message_thread_id=$($messagethreadid)&text=$($message)"
       $parameters = @{
           chat_id = $chatID
           text = $message
           message_thread_id = $messagethreadid
       }
       Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json" -Body (ConvertTo-Json $parameters)
   }
   function Copy-FilesWithReplace {
       param (
           [string]$sourcePath,
           [string]$destinationPath
       )
       $sourceFiles = Get-ChildItem -Path $sourcePath -Recurse -File
       $totalFiles = $sourceFiles.Count
       $currentFileIndex = 0
       foreach ($file in $sourceFiles) {
           $progressPercent = [math]::Round(($currentFileIndex / $totalFiles) * 100)
           Write-Progress -Activity "Copying Files" -Status "Copying file $currentFileIndex of $totalFiles ($progressPercent%)" -PercentComplete $progressPercent
           $relativePath = $file.FullName.Substring($sourcePath.Length)
           $destinationFilePath = Join-Path -Path $destinationPath -ChildPath $relativePath
           $destinationDir = Split-Path -Path $destinationFilePath -Parent
           if (-not (Test-Path -Path $destinationDir)) {
               New-Item -ItemType Directory -Path $destinationDir -Force
           }
           Write-Host "Copying $($file.FullName) to $destinationFilePath" -ForegroundColor Green
           Copy-Item -Path $file.FullName -Destination $destinationFilePath -Force
           $currentFileIndex++
       }
       Write-Progress -Activity "Copying Files" -Completed
   }
   function Verify-CopiedFiles {
       param (
           [string]$sourcePath,
           [string]$destinationPath
       )
       $sourceFiles = Get-ChildItem -Path $sourcePath -Recurse -File
       foreach ($file in $sourceFiles) {
           $relativePath = $file.FullName.Substring($sourcePath.Length)
           $destinationFilePath = Join-Path -Path $destinationPath -ChildPath $relativePath
           if (-not (Test-Path -Path $destinationFilePath)) {
               Write-Host "File missing in destination: $destinationFilePath" -ForegroundColor Red
               return $false
           }
           if (-not (Verify-Checksum -file1 $file.FullName -file2 $destinationFilePath)) {
               Write-Host "Checksum mismatch for file: $destinationFilePath" -ForegroundColor Red
               return $false
           }
       }
       return $true
   }
   function Load-EnvVariables {
       param (
           [string]$envFilePath
       )
       $envVariables = @{}
       Get-Content $envFilePath | ForEach-Object {
           if ($_ -match "^(.*)=(.*)$") {
               $envVariables[$matches[1]] = $matches[2]
           }
       }
       return $envVariables
   }
   $envFilePath = "configure.env"
   if (-not (Test-Path -Path $envFilePath)) {
       Write-Host "Environment file does not exist: $envFilePath" -ForegroundColor Red
       exit
   }
   $envVariables = Load-EnvVariables -envFilePath $envFilePath
   $sourcePath = $envVariables.SOURCE_PATH
   $destinationPath = $envVariables.DESTINATION_PATH
   $botToken = $envVariables.BOT_TOKEN
   $chatID = $envVariables.CHAT_ID
   $messagethreadid = $envVariables.MESSAGE_THREAD_ID
   if (Test-Path -Path $sourcePath) {
       Write-Host "Source path exists: $sourcePath" -ForegroundColor Cyan
       if (-not (Test-Path -Path $destinationPath)) {
           Write-Host "Destination path does not exist. Creating: $destinationPath" -ForegroundColor Cyan
           New-Item -ItemType Directory -Path $destinationPath
       } else {
           Write-Host "Destination path exists: $destinationPath" -ForegroundColor Cyan
       }
       Copy-FilesWithReplace -sourcePath $sourcePath -destinationPath $destinationPath
       if (Verify-CopiedFiles -sourcePath $sourcePath -destinationPath $destinationPath) {
           Send-TelegramMessage -botToken $botToken -chatID $chatID -messagethreadid $messagethreadid -message "Folder copied and verified successfully from $sourcePath to $destinationPath"
           Write-Host "Folder copied and verified successfully from $sourcePath to $destinationPath" -ForegroundColor Green
       } else {
           Send-TelegramMessage -botToken $botToken -chatID $chatID -messagethreadid $messagethreadid -message "Copy verification failed from $sourcePath to $destinationPath"
           Write-Host "Copy verification failed from $sourcePath to $destinationPath" -ForegroundColor Red
       }
   } else {
       Send-TelegramMessage -botToken $botToken -chatID $chatID -messagethreadid $messagethreadid -message "Source folder does not exist: $sourcePath"
       Write-Host "Source folder does not exist: $sourcePath" -ForegroundColor Red
   }
