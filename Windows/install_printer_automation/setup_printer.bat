@echo off
TITLE "Máy in Brother MFC-L2701DW"
set folderdriver=C:\temp\driver
set printername="Brother MFC-L2700DW series"
set ipprinter="192.168.1.5"
net use \\192.168.1.10\ibasic /user:minhthuan 123

echo Downloading printer driver from NAS...

xcopy \\192.168.1.10\ibasic\IBASIC\IT\Software\Driver_Printer\Brother\driver %folderdriver% /E /I /Q
:: Installing printer driver...
cscript "%folderdriver%\Prnmngr.vbs" -d -p "Brother MFC-L2701DW"
:: Tạo một cổng máy in
Cscript "%folderdriver%\Prnport.vbs" -a -r IP_%ipprinter% -h %ipprinter% -o raw -n 9100
:: Cài đặt driver từ NAS
Cscript "%folderdriver%\Prndrvr.vbs" -a -m %printername% -i %folderdriver%\BRPRM13A.INF -h %folderdriver%

:: Thêm máy in
Cscript "%folderdriver%\Prnmngr.vbs" -a -p "Brother MFC-L2701DW" -m %printername% -r IP_%ipprinter%


rd C:\temp /s /q

exit
exit