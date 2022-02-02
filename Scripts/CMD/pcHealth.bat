@echo off
::BatchHasAdmin
:-------------------------------------
REM --> Check if this file has administrator rights.
    IF "%PROCESSOR_ARCHITECTURE%" EQU "amd64" (
>nul 2>&1 "%SYSTEMROOT%\SysWOW64\cacls.exe" "%SYSTEMROOT%\SysWOW64\config\system"
) ELSE (
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
)

REM --> If no rights, we don't have setted the flag for it.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    set params= %*
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0"" %params:"=""%", "", "runas", 1 >> "%temp%\getadmin.vbs"

    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"
:--------------------------------------    
:: MainCode
@echo off
title pcHealth - Check your PC's Health! //_\\ v1.3.7-beta
cd /
color A
cls

:MENU
cls
color A
echo.
echo Thanks for downloading and using pcHealth!
echo Please be sure that you are running this Batch file in Administrator mode.
echo Made by REALSDEALS - Licensed under GNU-3 (You are free to use, but not to change or to remove this line.)
echo You are now using version 1.3.7-beta
echo.
echo %DATE%, %TIME%
echo.
echo ...........................................................
echo Enter number 1 to gather generic information about the system.
echo Enter number 2 to see which CPU and GPU are in the system.
echo Enter number 3 to run a system scan for missing/corrupt files.
echo Enter number 4 to try and repair missing/corrupt files.
echo Enter number 5 to run a system scan and to start an attempt on repairing missing/corrupt files.
echo Enter number 6 to generate a battery report. (Laptop only)
echo Enter number 7 to open the GUI to Windows Updates.
echo Enter number 8 to start a short ping test.
echo Enter number 9 to start a continues ping test.
echo Enter number 10 to re-open the generated battery report file.
echo Enter number 11 to re-open the CBS.log (AKA DISM.log)
echo Enter number 12 to get your Ninite! Includes Edge, Chrome, VLC and 7Zip.
echo Enter number 13 to see your systems Windows License key.
echo Enter number 14 to shutdown, reboot or log off from your PC/laptop.
echo Enter number 15 to enter a menu regarding usefull programs.
echo Enter number 16 to close this batch file.
echo ...........................................................
echo.
SET /P A=Type one of the numbers from the menu above to run the desired function, then press ENTER. Enter: 
IF %A%==1 GOTO SYSINFO
IF %A%==2 GOTO CPUANDGPUINFO
IF %A%==3 GOTO SCAN
IF %A%==4 GOTO DISM
IF %A%==5 GOTO SCSM
IF %A%==6 GOTO BATTERY
IF %A%==7 GOTO UPDATE
IF %A%==8 GOTO SHORTPING
IF %A%==9 GOTO CONTINUESPING
IF %A%==10 GOTO BATOPEN
IF %A%==11 GOTO OPENCBSLOG
IF %A%==12 GOTO NINITE
IF %A%==13 GOTO LICENSE
IF %A%==14 GOTO RESHUT
IF %A%==15 GOTO DOWNLOADABLES
IF %A%==16 GOTO CLOSE

:SYSINFO
cls
color C
systeminfo
pause
echo.
SET /P B=Enter number 1 to return to the menu, enter number 2 to exit. Enter: 
IF %B%==1 GOTO MENU
IF %B%==2 GOTO CLOSE

:SCAN
cls
color C
sfc /scannow
pause
echo.
SET /P C=If the scan found any corrupt files, enter number 1 to check the .log, enter number 2 when you want to return to the menu. Enter: 
IF %C%==1 GOTO OPENCBSLOG
IF %C%==2 GOTO MENU

:CPUANDGPUINFO
cls
color C 
echo. 
echo Your CPU information:
echo.
wmic cpu get caption, deviceid, name, numberofcores, maxclockspeed, status
echo.
echo Your GPU information:
echo.
wmic path win32_VideoController get name
pause
echo.
SET /P D=Enter number 1 to return to the menu, enter number 2 to exit. Enter: 
IF %D%==1 GOTO MENU
IF %D%==2 GOTO CLOSE

:DISM
cls
color C
DISM /online /cleanup-image /checkhealth
DISM /online /cleanup-image /scanhealth
pause
echo.
SET /P E=Enter number 1 to start an attempt on repairing, enter number 2 to return to the menu. Enter: 
IF %E%==1 GOTO DISMRESTORE
IF %E%==2 GOTO MENU

:DISMRESTORE
cls
color C
DISM /online /cleanup-image /restorehealth
pause
echo.
SET /P G=Enter number 1 to return to the menu, enter number 2 to exit. Enter: 
IF %G%==1 GOTO MENU
IF %G%==2 GOTO CLOSE

:SCSM
cls
color C
sfc /scannow
pause
echo.
SET /P H=If the scan found any corrupt files, enter number 1 to check the .log, enter number 2 to start an attempt to repair the corrupt/missing files, enter number 3 to return to the menu. Enter: 
IF %H%==1 GOTO SCSMOPENLOG
IF %H%==2 GOTO CONTINUE
IF %H%==3 GOTO MENU

:SCSMOPENLOG
cls
color C
start %windir%\explorer.exe "C:\Windows\Logs\CBS\CBS.log"
pause
echo.
SET /P I=Enter number 1 to start an attempt to repair the corrupt/missing files, if any are found... Enter number 2 to return to the main menu, enter number 3 to quit the script. Enter: 
IF %I%==1 GOTO CONTINUE
IF %I%==2 GOTO MENU
IF %I%==3 GOTO CLOSE

:CONTINUE
cls
color C
DISM /online /cleanup-image /checkhealth
DISM /online /cleanup-image /scanhealth
pause
DISM /online /cleanup-image /restorehealth
pause
echo.
SET /P J=Enter number 1 to return to the menu, enter number 2 to exit. Enter: 
IF %J%==1 GOTO MENU
IF %J%==2 GOTO CLOSE

:BATTERY
cls
color C
powercfg /batteryreport
pause
echo.
SET /P K=Enter number 1 to open the generated file, enter number 2 to return to the menu. Enter: 
IF %K%==1 GOTO BATOPEN
IF %K%==2 GOTO MENU

:UPDATE
cls
color C
control update
pause
echo.
SET /P L=Enter number 1 to return to the menu, enter number 2 to exit. Enter: 
IF %L%==1 GOTO MENU
IF %L%==2 GOTO CLOSE

:SHORTPING
cls
color C
ping 8.8.8.8 
pause
echo.
SET /P M=Enter number 1 to return to the menu, enter number 2 to start a continues ping test, enter number 3 to exit. Enter: 
IF %M%==1 GOTO MENU
IF %M%==2 GOTO CONTINUESPING
IF %M%==3 GOTO CLOSE

:CONTINUESPING
cls
color C
ping 8.8.8.8 -t -l 256
pause
echo.
SET /P N=Enter number 1 to return to the menu, enter number 2 to exit. Enter: 
IF %N%==1 GOTO MENU
IF %N%==2 GOTO CLOSE

:BATOPEN
cls
color C
start %windir%\explorer.exe "C:\battery-report.html"
pause
echo.
SET /P O=Enter number 1 to return to the menu, enter number 2 to exit. Enter: 
IF %O%==1 GOTO MENU
IF %O%==2 GOTO CLOSE

:OPENCBSLOG
cls
color C
start %windir%\explorer.exe "C:\Windows\Logs\CBS\CBS.log"
pause
echo.
SET /P P=Enter number 1 to return to the main menu, enter number 2 to exit. Enter: 
IF %P%==1 GOTO MENU
IF %P%==2 GOTO CLOSE

:NINITE
cls
color C
start "" https://ninite.com/7zip-chrome-edge-vlc/ninite.exe 
pause
echo.
SET /P Q=Enter number 1 to return to the main menu, enter number 2 to exit. Enter: 
IF %Q%==1 GOTO MENU
IF %Q%==2 GOTO CLOSE

:LICENSE
cls
color C
echo.
echo "Your systems license key:"
wmic path SoftwareLicensingService get OA3xOriginalProductKey
pause
echo.
SET /p R=If you want to return to the menu, enter number 1. To close the script, enter the number 2.
IF %R%==1 GOTO MENU
IF %R%==2 GOTO CLOSE

:RESHUT
cls
color C
echo. 
SET /P S=If you want to log off from your PC/Laptop enter number 1, to restart enter number 2, to shutdown enter number 3 and to return to the main menu enter number 4. Enter: 
IF %S%==1 GOTO LOGOFF1
IF %S%==2 GOTO RESTART2
IF %S%==3 GOTO SHUTDOWN3
IF %S%==4 GOTO CLOSE

:LOGOFF1
cls
color C 
echo. 
SET /P T=Are you sure that you want to log off your PC? Enter number 1, enter number 2 if you want to return to the menu. Enter: 
IF %T%==1 GOTO LOGOFFCONFIRM1
IF %T%==2 GOTO MENU 

:LOGOFFCONFIRM1
cls
color C  
shutdown /l 
EXIT /B

:RESTART2
cls
color C
echo.
SET /P U=Are you sure that you want to restart your PC? Enter number 1, to do so. Enter number 2 to return to the main menu. Enter: 
IF %U%==1 GOTO RESTARTCONFIRM2
IF %U%==2 GOTO MENU

:RESTARTCONFIRM2
cls
color C 
shutdown /r
EXIT /B

:SHUTDOWN3
cls
color C
echo. 
SET /P V=Are you sure that you want to shutdown your PC? Enter number 1, to continue. Enter number 2 to return to the main menu. Enter: 
IF %V%==1 GOTO SHUTDOWNCONFIRM3
IF %V%==2 GOTO MENU

:SHUTDOWNCONFIRM3
cls
color C
shutdown /s
EXIT /B

:DOWNLOADABLES
cls
color 8
echo.
echo You have now openend a menu to get direct download links to some usefull IT programs!
echo.
echo ...........................................................
echo Enter number 1 to get the latest official version of pcHealth!
echo Enter number 2 to get hardware info.
echo Enter number 3 to get ADW Cleaner.
echo Enter number 4 to get DiskInfo64.
echo Enter number 5 to get DiskMark64.
echo Enter number 6 to get Prime95.
echo Enter number 7 to return to the previous menu.
echo Enter number 8 to close the script.
echo ...........................................................
echo.
SET /P AB=Type one of the numbers above to run the desired function. ENTER: 
IF %AB%==1 GOTO PCHEALTHGETVER
IF %AB%==2 GOTO HARDINFODOWN
IF %AB%==3 GOTO ADWCLEANER
IF %AB%==4 GOTO DISKINFODOWN
IF %AB%==5 GOTO DISKMARKDOWN
IF %AB%==6 GOTO PRIMEDOWN
IF %AB%==7 GOTO MENU
IF %AB%==8 GOTO CLOSE

:PCHEALTHGETVER
cls
color 9
echo.
echo Are you sure that you want to download the newest version of pcHealth?
echo.
SET /P AC=If yes, enter the number 1, if not enter number 2 to return to the menu. ENTER: 
IF %AC%==1 start "" https://github.com/REALSDEALS/pcHealth/archive/refs/heads/main.zip 
IF %AC%==2 GOTO MENU 

:HARDINFODOWN
cls
color 9
echo.
echo Are you sure that you want to download the newest version of Hardware Info?
echo.
SET /P AD=If yes, enter the number 1, if not enter number 2 to return to the menu. ENTER: 
IF %AD%==1 start "" https://www.fosshub.com/HWiNFO.html?dwl=hwi_716.exe
IF %AD%==2 GOTO DOWNLOADABLES

:ADWCLEANER
cls
color 9
echo.
echo Are you sure that you want to download the latest version of ADW Cleaner? ENTER: 
echo. 
SET /P AE=If yes enter the number 1 to start the download, enter number 2 to return to the menu.
IF %AE%==1 start "" https://downloads.malwarebytes.com/file/adwcleaner
IF %AE%==2 GOTO MENU

:DISKINFODOWN
cls
color 9
echo. 
echo Are you sure that you want to download the latest version of Disk Info?
echo. 
SET /P AF=If yes enter the number 1 to start the download, enter the number 2 to return to the menu. ENTER: 
IF %AF%==1 start "" https://osdn.net/frs/redir.php?m=nchc&f=crystaldiskinfo%2F76462%2FCrystalDiskInfo8_13_3.zip
IF %AF%==2 GOTO MENU

:DISKMARKDOWN
cls
color 9
echo. 
echo Are you sure that you want to download the latest version of Disk Mark?
echo. 
SET /P AF=If yes enter the number 1 to start the download, enter the number 2 to return to the menu. ENTER: 
IF %AF%==1 start "" https://osdn.net/frs/redir.php?m=nchc&f=crystaldiskmark%2F75540%2FCrystalDiskMark8_0_4.zip
IF %AF%==2 GOTO MENU

:PRIMEDOWN
cls
color 9
echo. 
echo Are you sure that you want to download the latest version of Prime95? ENTER: 
echo. 
SET /P AF=If yes enter the number 1 to start the download, enter the number 2 to return to the menu.
IF %AF%==1 start "" https://www.guru3d.com/files-get/prime95-download,3.html
IF %AF%==2 GOTO MENU

:CLOSE
EXIT /B