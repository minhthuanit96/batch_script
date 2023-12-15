@echo off
TITLE "INSTALL PRINTER FOR WINDOWS"                                                                                                                                       
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo  Run CMD as Administrator...
    goto goUAC
) else (
 goto goADMIN )

REM Go UAC to get Admin privileges
:goUAC
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    set params = %*:"=""
    echo UAC.ShellExecute "cmd.exe", "/c %~s0 %params%", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:goADMIN
    pushd "%CD%"
    CD /D "%~dp0"
REM ========================================================================================================================================
echo " ____  ____     ___  _____   ___  ____   ______    ___  ___        ____   __ __      ______  __ __  __ __   ____  ____       ____  ______ ";
echo "|    \|    \   /  _]/ ___/  /  _]|    \ |      |  /  _]|   \      |    \ |  |  |    |      ||  |  ||  |  | /    ||    \     |    ||      |";
echo "|  o  )  D  ) /  [_(   \_  /  [_ |  _  ||      | /  [_ |    \     |  o  )|  |  |    |      ||  |  ||  |  ||  o  ||  _  |     |  | |      |";
echo "|   _/|    / |    _]\__  ||    _]|  |  ||_|  |_||    _]|  D  |    |     ||  ~  |    |_|  |_||  _  ||  |  ||     ||  |  |     |  | |_|  |_|";
echo "|  |  |    \ |   [_ /  \ ||   [_ |  |  |  |  |  |   [_ |     |    |  O  ||___, |      |  |  |  |  ||  :  ||  _  ||  |  |     |  |   |  |  ";
echo "|  |  |  .  \|     |\    ||     ||  |  |  |  |  |     ||     |    |     ||     |      |  |  |  |  ||     ||  |  ||  |  |     |  |   |  |  ";
echo "|__|  |__|\_||_____| \___||_____||__|__|  |__|  |_____||_____|    |_____||____/       |__|  |__|__| \__,_||__|__||__|__|    |____|  |__|  ";
echo "                                                                                                                                             
REM ========================================================================================================================================
set folderdriver=C:\temp\driver
net use \\192.168.1.10\ibasic /user:minhthuan 123
REM ========================================================================================================================================
:main
@echo off
set "appversion=v1.0"
setlocal
title Main Menu
echo.
echo %appversion%
echo    ==================================================================
echo    [1] Install Brother MFC-L2701DW (IT's PRINTER)           : Press 1
echo    [2] Install Brother HL-L2360DW  (PRODUCTION's PRINTER)   : Press 2
echo    [3] Install Gestetner MP 5054 (PHOTOCOPY)                : Press 3
echo    [4] Install Brother HL-L8350CDW (COLOR PRINTER)          : Press 4
echo    [5] Exit                                                 : Press 5
echo    ==================================================================
Choice /N /C 12345 /M " Your choice is :"
if %ERRORLEVEL% == 5 call :timeout & goto exits
if %ERRORLEVEL% == 4 call :Install-Brother-HL-L8350CDW-series & goto main
if %ERRORLEVEL% == 3 call :Install-Gestetner-MP-5054-PCL-6 & goto main
if %ERRORLEVEL% == 2 call :Install-Brother-HL-L2360DW & goto main
if %ERRORLEVEL% == 1 call :Install-Brother-MFC-L2701DW & goto main
endlocal
goto end
REM ========================================================================================================================================
echo The process is still active....
:Install-Brother-MFC-L2701DW  
setlocal
set printername="Brother MFC-L2700DW series"
set ipprinter="192.168.1.5"

:: Downloading printer driver from NAS...
xcopy \\192.168.1.10\ibasic\IBASIC\IT\Software\Driver_Printer\Brother\MFC-L2700DW %folderdriver% /E /I /Q
:: Installing printer driver...
cscript "%folderdriver%\Prnmngr.vbs" -d -p "Brother MFC-L2701DW"
:: Create a new port for printer
Cscript "%folderdriver%\Prnport.vbs" -a -r IP_%ipprinter% -h %ipprinter% -o raw -n 9100
:: Install driver printer
Cscript "%folderdriver%\Prndrvr.vbs" -a -m %printername% -i %folderdriver%\BRPRM13A.INF -h %folderdriver%
:: Add The new printer
Cscript "%folderdriver%\Prnmngr.vbs" -a -p "Brother MFC-L2701DW" -m %printername% -r IP_%ipprinter%
rd C:\temp /s /q
cls
endlocal
goto :EOF
REM =========================================================================================================================================
echo The process is still active....
:Install-Brother-HL-L2360DW
setlocal
set printername="Brother HL-L2360D series"
set ipprinter="192.168.1.3"

:: Downloading printer driver from NAS...
xcopy \\192.168.1.10\ibasic\IBASIC\IT\Software\Driver_Printer\Brother\HL-L2360DW %folderdriver% /E /I /Q
:: Installing printer driver...
cscript "%folderdriver%\Prnmngr.vbs" -d -p "Brother HL-L2360D series"
:: Create a new port for printer
Cscript "%folderdriver%\Prnport.vbs" -a -r IP_%ipprinter% -h %ipprinter% -o raw -n 9100
:: Install driver printer
Cscript "%folderdriver%\Prndrvr.vbs" -a -m %printername% -i %folderdriver%\BROHL13A.INF -h %folderdriver%
:: Add The new printer
Cscript "%folderdriver%\Prnmngr.vbs" -a -p "Brother HL-L2360D series" -m %printername% -r IP_%ipprinter%
rd C:\temp /s /q
cls
endlocal
goto :EOF
REM =========================================================================================================================================
echo The process is still active....
:Install-Gestetner-MP-5054-PCL-6
setlocal
set printername="Gestetner MP 5054 PCL 6"
set ipprinter="192.168.1.249"

:: Downloading printer driver from NAS...
xcopy \\192.168.1.10\ibasic\IBASIC\IT\Software\Driver_Printer\RICOH\z94640L16\disk1 %folderdriver% /E /I /Q
:: Installing printer driver...
cscript "%folderdriver%\Prnmngr.vbs" -d -p "Gestetner MP 5054 PCL 6"
:: Create a new port for printer
Cscript "%folderdriver%\Prnport.vbs" -a -r IP_%ipprinter% -h %ipprinter% -o raw -n 9100
:: Install driver printer
Cscript "%folderdriver%\Prndrvr.vbs" -a -m %printername% -i %folderdriver%\oemsetup.inf -h %folderdriver%
:: Add The new printer
Cscript "%folderdriver%\Prnmngr.vbs" -a -p "Gestetner MP 5054 PCL 6" -m %printername% -r IP_%ipprinter%
rd C:\temp /s /q
cls
endlocal
goto :EOF
REM =========================================================================================================================================
echo The process is still active....
:Install-Brother-HL-L8350CDW-series
setlocal
set printername="Brother HL-L8350CDW series"
set ipprinter="192.168.1.7"

:: Downloading printer driver from NAS...
xcopy \\192.168.1.10\ibasic\IBASIC\IT\Software\Driver_Printer\Brother\HL-L8350CDW %folderdriver% /E /I /Q
:: Installing printer driver...
cscript "%folderdriver%\Prnmngr.vbs" -d -p "Brother HL-L8350CDW series"
:: Create a new port for printer
Cscript "%folderdriver%\Prnport.vbs" -a -r IP_%ipprinter% -h %ipprinter% -o raw -n 9100
:: Install driver printer
Cscript "%folderdriver%\Prndrvr.vbs" -a -m %printername% -i %folderdriver%\BROCH13A.INF -h %folderdriver%
:: Add The new printer
Cscript "%folderdriver%\Prnmngr.vbs" -a -p "Brother HL-L8350CDW series" -m %printername% -r IP_%ipprinter%
rd C:\temp /s /q
cls
endlocal
goto :EOF
REM =========================================================================================================================================
:timeout
cls
echo Installation Completed
echo " ______ __  __  ___  __  __ __ __    _  _   ___   __ __     ____   ___   ____     __ __  __  __ __  __   ___ "
echo " | || | ||  || // \\ ||\ || || //    \\//  // \\  || ||    ||     // \\  || \\    || || (( \ || ||\ ||  // \\"
echo "   ||   ||==|| ||=|| ||\\|| ||<<      )/  ((   )) || ||    ||==  ((   )) ||_//    || ||  \\  || ||\\|| (( ___"
echo "   ||   ||  || || || || \|| || \\    //    \\_//  \\_//    ||     \\_//  || \\    \\_// \_)) || || \||  \\_||"                                                                                                                                                                                                                                                ";                                                                                                                    
timeout /t 5 /nobreak>nul
exit
