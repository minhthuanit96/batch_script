@echo off
set /p newHostname=Enter the new hostname: 
set /p newUser=Enter the new username: 
:: Change Hostname
wmic computersystem where caption='%COMPUTERNAME%' call rename name="%newHostname%"
:: Change Username
wmic useraccount where name='%USERNAME%' rename "%newUser%"
:: Display Success Message
echo Hostname and Username changed successfully!
:: Restart the computer to apply changes
shutdown /r /t 0
