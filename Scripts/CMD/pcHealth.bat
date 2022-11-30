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
title pcHealth - Check your PC's Health! - version 1.6.1-beta
cd /
color D
cls

:MENU
cls
color 79
echo.
echo Thanks for downloading and using pcHealth!
echo Please be sure that you are running this Batch file in Administrator mode.
echo.
echo Made by REALSDEALS - Licensed under GNU-3 (You are free to use, but not to change or to remove this line.)
echo You are now using version 1.6.1-beta
echo.
echo %DATE%, %TIME%
echo.
echo ...........................................................
echo Enter number 1 to open a menu regarding testing scripts.
echo Enter number 2 to open a menu regarding programs for testing /w downloadable redirects.
echo Enter number 3 to go to the repository of pcHealth.
echo Enter number 4 to close this batch script.
echo ...........................................................
echo.

SET /P A=Type one of the numbers from the menu above to open the desired menu and then press ENTER. Enter: 
IF %A%==1 GOTO TOOLS
IF %A%==2 GOTO PROGRAMS
IF %A%==3 GOTO PCHEALTHGETVER
IF %A%==4 GOTO CLOSE

:TOOLS
cls 
color 09
echo.
echo ...........................................................
echo Enter number 1 to gather generic information about the system.
echo Enter number 2 to see which CPU and GPU are in the system.
echo Enter number 3 to run a system scan for missing/corrupt files.
echo Enter number 4 to try and repair missing/corrupt files.
echo Enter number 5 to run a system scan and to start an attempt on repairing missing/corrupt files.
echo Enter number 6 to generate a battery report. (Laptop only)
echo Enter number 7 to open the GUI to Windows Updates.
echo Enter number 8 to open a menu regarding Disk Optimization. (Windows Function)
echo Enter number 9 to start Disk cleaner to clean your drive(s). (Windows Function)
echo Enter number 10 to start a short ping test.
echo Enter number 11 to start a continues ping test.
echo Enter number 12 to start a trace route to Google.
echo Enter number 13 to update system programs.
echo Enter number 14 to re-start the audio drivers of your system.
echo Enter number 15 to re-open the generated battery report file.
echo Enter number 16 to re-open the CBS.log (AKA DISM.log)
echo Enter number 17 to get your Ninite! Includes Edge, Chrome, VLC and 7Zip.
echo Enter number 18 to see your systems Windows License key.
echo Enter number 19 BIOS Password Recovery.
echo Enter number 20 to shutdown, reboot or log off from your PC/laptop.
echo Enter number 21 to open the programs menu.
echo Enter number 22 to return to the previous menu.
echo Enter number 23 to close this batch file.
echo ...........................................................
echo.

SET /P B=Type one of the numbers from the menu above to run the desired function, then press ENTER. Enter: 
IF %B%==1 GOTO SYSINFO
IF %B%==2 GOTO CPUANDGPUINFO
IF %B%==3 GOTO SCAN
IF %B%==4 GOTO DISM
IF %B%==5 GOTO SCSM
IF %B%==6 GOTO BATTERY
IF %B%==7 GOTO UPDATE
IF %B%==8 GOTO DFR
IF %B%==9 GOTO CLMGR
IF %B%==10 GOTO SHORTPING
IF %B%==11 GOTO CONTINUESPING
IF %B%==12 GOTO TRACEGOOGLE
IF %B%==13 GOTO SYSUPDATE
IF %B%==14 GOTO AUDIORE 
IF %B%==15 GOTO BATOPEN
IF %B%==16 GOTO OPENCBSLOG
IF %B%==17 GOTO NINITE
IF %B%==18 GOTO LICENSE
IF %B%==19 GOTO BIOSPW
IF %B%==20 GOTO RESHUT
IF %B%==21 GOTO PROGRAMS
IF %B%==22 GOTO MENU
IF %B%==23 GOTO CLOSE

:PROGRAMS
cls
color 0B
echo.
echo ...........................................................
echo Enter number 1 to get hardware info.
echo Enter number 2 to get ADW Cleaner.
echo Enter number 3 to get DiskInfo64.
echo Enter number 4 to get DiskMark64.
echo Enter number 5 to get Prime95.
echo Enter number 6 to open the tools menu.
echo Enter number 7 to return to the previous menu.
echo Enter number 8 to close the script.
echo ...........................................................
echo.

SET /P AB=Type one of the numbers above to run the desired function. Enter: 
IF %AB%==1 GOTO HARDINFODOWN
IF %AB%==2 GOTO ADWCLEANER
IF %AB%==3 GOTO DISKINFODOWN
IF %AB%==4 GOTO DISKMARKDOWN
IF %AB%==5 GOTO PRIMEDOWN
IF %AB%==6 GOTO TOOLS
IF %AB%==7 GOTO MENU
IF %AB%==8 GOTO CLOSE

:SYSUPDATE
cls
color 0A
winget upgrade --all
pause
echo.
SET /P LL=Enter number 1 to return to the sub-menu, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %LL%==1 GOTO TOOLS
IF %LL%==2 GOTO MENU
IF %LL%==3 GOTO CLOSE

:SYSINFO
cls
color 0A
systeminfo
pause
echo.
SET /P C=Enter number 1 to return to the sub-menu, enter number 2 to go back to the main menu or enter number 3 to close the script. Enter: 
IF %C%==1 GOTO TOOLS
IF %C%==2 GOTO MENU
IF %C%==3 GOTO CLOSE

:SCAN
cls
color 0A
sfc /scannow
pause
echo.
SET /P D=If the scan found any corrupt files, enter number 1 to check the .log, enter number 2 to return to the previous sub-menu, enter number 3 when you want to return to the menu or enter number 4 to close the script. Enter: 
IF %D%==1 GOTO OPENCBSLOG
IF %D%==2 GOTO TOOLS
IF %D%==3 GOTO MENU
IF %D%==4 GOTO CLOSE

:CPUANDGPUINFO
cls
color 0A 
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
SET /P E=Enter number 1 to return to the sub-menu, enter number 2 to go back to the main menu or enter number 3 to close the script. Enter: 
IF %E%==1 GOTO TOOLS
IF %E%==2 GOTO MENU
IF %E%==3 GOTO CLOSE

:DISM
cls
color 0A
DISM /online /cleanup-image /checkhealth
DISM /online /cleanup-image /scanhealth
pause
echo.
SET /P F=Enter number 1 to start an attempt on repairing, enter number 2 to return to the previous sub-menu, number 3 for the main-menu or number 4 to exit the script. Enter: 
IF %F%==1 GOTO DISMRESTORE
IF %F%==2 GOTO TOOLS
IF %F%==3 GOTO MENU
IF %F%==4 GOTO CLOSE

:DISMRESTORE
cls
color 0A
DISM /online /cleanup-image /restorehealth
pause
echo.
SET /P G=Enter number 1 to return to the sub-menu, enter number 2 to go back to the main menu or enter number 3 to close the script. Enter: 
IF %G%==1 GOTO TOOLS
IF %G%==2 GOTO MENU
IF %G%==3 GOTO CLOSE

:SCSM
cls
color 0A
sfc /scannow
pause
echo.
SET /P H=If the scan found any corrupt files, enter number 1 to check the .log, enter number 2 to start an attempt to repair the corrupt/missing files,enter number 3 to return to the previous sub-menu, enter number 4 to return to the main-menu or enter number 5 to exit the script. Enter: 
IF %H%==1 GOTO SCSMOPENLOG
IF %H%==2 GOTO CONTINUE
IF %H%==3 GOTO TOOLS
IF %H%==4 GOTO MENU
IF %H%==5 GOTO CLOSE

:SCSMOPENLOG
cls
color 0A
start %windir%\explorer.exe "C:\Windows\Logs\CBS\CBS.log"
pause
echo.
SET /P I=Enter number 1 to start an attempt to repair the corrupt/missing files, if any are found... Enter number 2 to return to the previous sub-menu, enter number 3 to return to the main-menu or enter number 4 to exit the script. Enter: 
IF %I%==1 GOTO CONTINUE
IF %I%==2 GOTO TOOLS
IF %I%==3 GOTO MENU
IF %I%==4 GOTO CLOSE

:CONTINUE
cls
color 0A
DISM /online /cleanup-image /checkhealth
DISM /online /cleanup-image /scanhealth
pause
DISM /online /cleanup-image /restorehealth
pause
echo.
SET /P J=Enter number 1 to return to the previous sub-menu, enter number 2 to return to the main-menu or enter number 3 to exit. Enter: 
IF %J%==1 GOTO TOOLS
IF %J%==2 GOTO MENU
IF %J%==3 GOTO CLOSE

:BATTERY
cls
color 0A
powercfg /batteryreport
pause
echo.
SET /P K=Enter number 1 to open the generated file, enter number 2 to return to the previous sub-menu, number 3 to return to the main-menu or enter number 4 to exit the script. Enter: 
IF %K%==1 GOTO BATOPEN
IF %K%==2 GOTO TOOLS
IF %K%==3 GOTO MENU
IF %K%==4 GOTO CLOSE

:UPDATE
cls
color 0A
control update
pause
echo.
SET /P L=Enter number 1 to return to the previous sub-menu, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %L%==1 GOTO TOOLS
IF %L%==2 GOTO MENU
IF %L%==3 GOTO CLOSE

:DFR
cls
color 0A
dfrgui.exe 
pause
echo. 
SET /P LK=Enter number 1 to return to the previous sub-menu, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %L%==1 GOTO TOOLS
IF %L%==2 GOTO MENU
IF %L%==3 GOTO CLOSE

:CLMGR
cls
color 0A
cleanmgr.exe
pause
echo. 
SET /P LKT=Enter number 1 to return to the previous sub-menu, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %L%==1 GOTO TOOLS
IF %L%==2 GOTO MENU
IF %L%==3 GOTO CLOSE

:SHORTPING
cls
color 0A
ping 8.8.8.8 
pause
echo.
SET /P M=Enter number 1 to return to the previous sub-menu, enter number 2 to return to the main-menu, enter number 3 to start a continues ping test or enter number 4 to exit the script. Enter: 
IF %M%==1 GOTO TOOLS
IF %M%==2 GOTO MENU
IF %M%==3 GOTO CONTINUESPING
IF %M%==4 GOTO CLOSE

:CONTINUESPING
cls
color 0A
ping 8.8.8.8 -t -l 256
pause
echo.
SET /P N=Enter number 1 to return to the previous sub-menu menu, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %N%==1 GOTO TOOLS
IF %N%==2 GOTO MENU
IF %N%==2 GOTO CLOSE

:TRACEGOOGLE
cls
color 0A
echo.
echo Starting a trace route to Google with a maximum of '30' hops.
echo.
tracert www.google.com
pause
echo.
SET /P NM=Enter number 1 to return to the previous sub-menu menu, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %NM%==1 GOTO TOOLS
IF %NM%==2 GOTO MENU
IF %NM%==3 GOTO CLOSE

:AUDIORE
cls
color 0A
if "%1"=="am_admin" (powershell start -verb runas '%0' am_admin) 
net stop audiosrv
net stop AudioEndPointBuilder
net start AudioEndPointBuilder
net start audiosrv
echo.
echo Your audio drivers have been reset, hope it solved your audio problem!
echo.
pause
GOTO TOOLS

:BATOPEN
cls
color 0A
start %windir%\explorer.exe "C:\battery-report.html"
pause
echo.
SET /P O=Enter number 1 to return to the previous sub-menu, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %O%==1 GOTO TOOLS
IF %O%==2 GOTO MENU
IF %O%==3 GOTO CLOSE

:OPENCBSLOG
cls
color 0A
start %windir%\explorer.exe "C:\Windows\Logs\CBS\CBS.log"
pause
echo.
SET /P P=Enter number 1 to return to the previous sub-menu, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %P%==1 GOTO TOOLS
IF %P%==2 GOTO MENU
IF %P%==3 GOTO CLOSE

:NINITE
cls
color 0A
start "" https://ninite.com/7zip-chrome-edge-vlc/ninite.exe 
pause
echo.
SET /P Q=Enter number 1 to return to the previous sub-menu, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %Q%==1 GOTO TOOLS
IF %Q%==2 GOTO MENU
IF %Q%==3 GOTO CLOSE

:LICENSE
cls
color 0A
echo.
echo "Your systems license key:"
wmic path SoftwareLicensingService get OA3xOriginalProductKey
pause
color 0E
echo.
echo If it didn't showed a key, it is possible that this PC is using a 'illegal' key, or a key that was used for a previous installation of Windows 7/8 - then upgraded to 10/11.
echo.
echo You can also try to use a different script for the license key, you can find it in the 'Scripts' folder in this pcHealth folder!
echo.
SET /p R=If you want to return to the previous sub-menu, enter number 1. To return to the main-menu, enter number 2. To exit the script, enter the number 3. Enter: 
IF %R%==1 GOTO TOOLS
IF %R%==2 GOTO MENU
IF %R%==2 GOTO CLOSE

:BIOSPW
cls
color 0E
echo.
echo The BIOS Password Recovery tool is a website that can be used to gather/generate a recovery code for the BIOS.
echo.
echo If you don't know how to use this function/website, then 
echo I would suggest that you enter '2' on the next line to learn more.
echo. 
echo The credits for this function and repository goes to the owner: @bacher09
echo.
SET /P SK=Enter number 1 to visit the website, enter number 2 to go to the repository of BIOS-PW and learn more! Enter number 3 to return to the sub-menu, enter number 4 to return to the main-menu or enter number 5 to close the script. Enter: 
IF %SK%==1 start "" https://bios-pw.org && GOTO BIOSPW
IF %SK%==2 start "" https://github.com/bacher09/pwgen-for-bios && GOTO BIOSPW
IF %SK%==3 GOTO TOOLS
IF %SK%==4 GOTO MENU
IF %SK%==5 GOTO CLOSE 

:RESHUT
cls
color 0A
echo. 
SET /P S=If you want to log off from your PC/Laptop enter number 1, to restart enter number 2, to shutdown enter number 3 and to return to the previous sub-menu enter number 4 or to exit the script... enter number 5. Enter: 
IF %S%==1 GOTO LOGOFF1
IF %S%==2 GOTO RESTART2
IF %S%==3 GOTO SHUTDOWN3
IF %S%==4 GOTO TOOLS
IF %S%==5 GOTO CLOSE

:LOGOFF1
cls
color 0A 
echo. 
SET /P T=Are you sure that you want to log off your PC? Enter number 1, enter number 2 to return to the previous sub-menu, enter number 3 to return to the main-menu or enter number 4 to exit the script. Enter: 
IF %T%==1 GOTO LOGOFFCONFIRM1
IF %T%==2 GOTO TOOLS
IF %T%==3 GOTO MENU 
IF %T%==4 GOTO CLOSE

:LOGOFFCONFIRM1
cls
color 0A  
shutdown /l 
EXIT /B

:RESTART2
cls
color 0A
echo.
SET /P U=Are you sure that you want to restart your PC? Enter number 1, to do so. Enter number 2 to return to the previous sub-menu, enter number 3 to return to the main-menu or enter number 4 to exit the script. Enter: 
IF %U%==1 GOTO RESTARTCONFIRM2
IF %U%==2 GOTO TOOLS
IF %U%==3 GOTO MENU
IF %U%==4 GOTO CLOSE

:RESTARTCONFIRM2
cls
color 0A 
shutdown /r
EXIT /B

:SHUTDOWN3
cls
color 0A
echo. 
SET /P V=Are you sure that you want to shutdown your PC? Enter number 1, to continue. Enter number 2 to return to the previous sub-menu, enter number 3 to return to the main-menu or enter number 4 to exit the script. Enter: 
IF %V%==1 GOTO SHUTDOWNCONFIRM3
IF %V%==2 GOTO TOOLS 
IF %V%==3 GOTO MENU
IF %V%==4 GOTO CLOSE

:SHUTDOWNCONFIRM3
cls
color 0A
shutdown /s
EXIT /B

:PCHEALTHGETVER
cls
color 0A
echo.
echo Are you sure that you want to download the newest version of pcHealth?
echo.
SET /P AC=If yes, enter the number 1, if not enter number 2 to return to the previous sub-menu. Enter: 
IF %AC%==1 GOTO PCHEALTHGETVERDOWNLOADLINK
IF %AC%==2 GOTO PROGRAMS 

:PCHEALTHGETVERDOWNLOADLINK
cls
color 0A
echo.
echo Your download will start now!
echo.
start "" https://github.com/REALSDEALS/pcHealth/archive/refs/heads/main.zip 
echo.
SET /P AD=To return to the sub-menu enter 1, to return to the main menu enter 2 or to close the script enter 3. Enter: 
IF %AD%==1 GOTO PROGRAMS
IF %AD%==2 GOTO MENU
IF %AD%==3 GOTO CLOSE
 
:HARDINFODOWN
cls
color 0A
echo.
echo Are you sure that you want to download the newest version of Hardware Info?
echo.
SET /P AE=If yes, enter the number 1, if not enter number 2 to return to the sub-menu. Enter: 
IF %AE%==1 GOTO HARDINFODOWNLOADLINK 
IF %AE%==2 GOTO PROGRAMS

:HARDINFODOWNLOADLINK
cls
color 0A
echo.
echo Your download will start now; if not click on 'installer' on the download page!
echo.
start "" https://www.fosshub.com/HWiNFO.html?dwl=hwi_726.exe
echo.
SET /P AF=To return to the previous sub-menu enter 1, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %AF%==1 GOTO PROGRAMS
IF %AF%==2 GOTO MENU
IF %AF%==3 GOTO CLOSE

:ADWCLEANER
cls
color 0A
echo.
echo Are you sure that you want to download the latest version of ADW Cleaner?
echo. 
SET /P AG=If yes enter the number 1 to start the download, enter number 2 to return to the previous sub-menu. Enter: 
IF %AG%==1 GOTO ADWCLEANERDOWNLOADLINK
IF %AG%==2 GOTO PROGRAMS

:ADWCLEANERDOWNLOADLINK
cls
color 0A
echo. 
echo Your download will start now!
echo.
start "" https://downloads.malwarebytes.com/file/adwcleaner
echo.
SET /P AH=To return to the previous sub-menu enter 1, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %AH%==1 GOTO PROGRAMS
IF %AH%==2 GOTO MENU
IF %AH%==3 GOTO CLOSE

:DISKINFODOWN
cls
color 0A
echo. 
echo Are you sure that you want to download the latest version of Disk Info?
echo. 
SET /P AI=If yes enter the number 1 to start the download, enter the number 2 to return to the previous sub-menu. Enter: 
IF %AI%==1 GOTO DISKINFODOWNLOADLINK
IF %AI%==2 GOTO PROGRAMS

:DISKINFODOWNLOADLINK
cls
color 0A
echo.
echo Your download will start now!
start "" https://osdn.net/projects/crystaldiskinfo/downloads/77538/CrystalDiskInfo8_17_4.zip/
echo.
SET /P AJ=To return to the previous sub-menu enter 1, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %AJ%==1 GOTO PROGRAMS
IF %AJ%==2 GOTO MENU
IF %AJ%==3 GOTO CLOSE

:DISKMARKDOWN
cls
color 0A
echo. 
echo Are you sure that you want to download the latest version of Disk Mark?
echo. 
SET /P AK=If yes enter the number 1 to start the download, enter the number 2 to return to the previous sub-menu. Enter: 
IF %AK%==1 GOTO DISKMARKDOWNLOADLINK
IF %AK%==2 GOTO PROGRAMS

:DISKMARKDOWNLOADLINK
cls
color 0A
echo.
echo Your download will start now!
start "" https://osdn.net/projects/crystaldiskmark/downloads/77539/CrystalDiskMark8_0_4b.zip/
echo.
SET /P AL=To return to the previous sub-menu enter 1, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %AL%==1 GOTO PROGRAMS
IF %AL%==2 GOTO MENU
IF %AL%==3 GOTO CLOSE

:PRIMEDOWN
cls
color 0A
echo. 
echo Are you sure that you want to download the latest version of Prime95? Enter: 
echo. 
SET /P AM=If yes enter the number 1 to start the download, enter the number 2 to return to the previous sub-menu.
IF %AM%==1 GOTO PRIMEDOWNLOADLINK
IF %AM%==2 GOTO PROGRAMS

:PRIMEDOWNLOADLINK
cls
color 0A
echo.
echo Your download will start now!
start "" https://www.guru3d.com/files-get/prime95-download,3.html
echo.
SET /P AN=To return to the previous sub-menu enter 1, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %AN%==1 GOTO PROGRAMS
IF %AN%==2 GOTO MENU
IF %AN%==3 GOTO CLOSE

:CLOSE
EXIT /B