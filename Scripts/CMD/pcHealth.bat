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
title pcHealth - Check your PC's Health! - version 1.8.5-beta
=======
cd /
color D
cls

:MENU
cls
color f3
echo.
echo Thanks for downloading and using pcHealth!
echo Please be sure that you are running this Batch file in Administrator mode.
echo.
echo Made by REALSDEALS - Licensed under GNU-3 (You are free to use, but not to change or to remove this line.)
echo You are now using version 1.8.5-beta of pcHealth.
=======
echo.
for /f "skip=2 tokens=1,2,*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" /v LastLoggedOnDisplayName 2^>nul') do set FullName=%%c
if "%FullName%"=="" set FullName=%USERNAME%
echo Hello %FullName%!
echo Today it is '%DATE%' and the time is '%TIME%'
echo.
echo ...........................................................
echo Enter number 1 to open a menu regarding testing scripts.
echo Enter number 2 to open a menu regarding programs for testing /w downloadable redirects.
echo Enter number 3 to go to the repository of pcHealth.
echo Enter number 4 to check for pre-releases.
echo Enter number 5 to learn more about pcHealthPlus.
echo Enter number 6 to close this batch script.
echo ...........................................................
echo.

SET /P A=Type one of the numbers from the menu above to open the desired menu and then press ENTER. Enter: 
IF %A%==1 GOTO TOOLS
IF %A%==2 GOTO PROGRAMS
IF %A%==3 GOTO PCHEALTHGETVER
IF %A%==4 GOTO PRERELEASE
IF %A%==5 GOTO PCHEALTHPLUSVS
IF %A%==6 GOTO CLOSE

:TOOLS
cls 
color fc
echo.
echo        You are now in the Tools menu:
echo.
echo ...........................................................
echo Enter number 1 to gather generic information about the system.
echo Enter number 2 to show CPU, GPU and RAM information.
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
echo Enter number 13 to reset the network stack (may improve DNS resolve times)
echo Enter number 14 to update system programs.
echo Enter number 15 to update system drivers. (Currently HP only)
echo Enter number 16 to re-start the audio drivers of your system.
echo Enter number 17 to re-open the generated battery report file.
echo Enter number 18 to re-open the CBS.log (AKA DISM.log)
echo Enter number 19 to get your Ninite! Includes Edge, Chrome, VLC and 7Zip.
echo Enter number 20 to see your systems Windows License key.
echo Enter number 21 BIOS Password Recovery.
echo Enter number 22 to shutdown, reboot or log off from your PC/laptop.
echo Enter number 23 to open the programs menu.
echo Enter number 24 to return to the previous menu.
echo Enter number 25 to close this batch file.
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
IF %B%==13 GOTO RESETNETWORK
IF %B%==14 GOTO SYSUPDATE
IF %B%==15 GOTO HPUPDATE
IF %B%==16 GOTO AUDIORE
IF %B%==17 GOTO BATOPEN
IF %B%==18 GOTO OPENCBSLOG
IF %B%==19 GOTO NINITE
IF %B%==20 GOTO LICENSE
IF %B%==21 GOTO BIOSPW
IF %B%==22 GOTO RESHUT
IF %B%==23 GOTO PROGRAMS
IF %B%==24 GOTO MENU
IF %B%==25 GOTO CLOSE

:PROGRAMS
cls
color fA
echo.
echo        You are now in the Programs menu:
echo.
echo ...........................................................
echo Enter number 1 to get HWiNFO 64.
echo Enter number 2 to get HWMonitor.
echo Enter number 3 to get Malwarebytes ADW Cleaner.
echo Enter number 4 to get CrystalDiskInfo.
echo Enter number 5 to get CrystalDiskMark.
echo Enter number 6 to get Prime95.
echo Enter number 7 to install Windows PowerToys.
echo Enter number 8 to open the tools menu.
echo Enter number 9 to return to the previous menu.
echo Enter number 10 to close the script.
echo ...........................................................
echo.

SET /P AB=Type one of the numbers above to run the desired function. Enter: 
IF %AB%==1 GOTO HARDINFODOWN
IF %AB%==2 GOTO HWMONITORDOWN
IF %AB%==3 GOTO ADWCLEANER
IF %AB%==4 GOTO DISKINFODOWN
IF %AB%==5 GOTO DISKMARKDOWN
IF %AB%==6 GOTO PRIMEDOWN
IF %AB%==7 GOTO POWERTOYS
IF %AB%==8 GOTO TOOLS
IF %AB%==9 GOTO MENU
IF %AB%==10 GOTO CLOSE

:SYSUPDATE
cls
color 0A
echo Detected the following updatable packages:
winget upgrade
echo.
set /p update_choice="Do you want to continue updating? (y/n): "
if /i "%update_choice%"=="y" (
    echo Updating packages...
    winget upgrade --all --accept-source-agreements --accept-package-agreements --silent --force
) else (
    echo Update aborted.
)
pause
echo.
SET /P LL=Enter number 1 to return to the sub-menu, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %LL%==1 GOTO TOOLS
IF %LL%==2 GOTO MENU
IF %LL%==3 GOTO CLOSE

:HPUPDATE
cls
color 0A
winget install --id HP.ImageAssistant
echo.
echo -----------------------------------------------------
echo Please navigate to: C:\SWSetup
echo and search for "HPImageAssistant.exe". Running this tool will scan your HP system for outdated drivers and firmware.
pause
echo.
echo ====================================================
echo                HP IMAGE ASSISTANT MENU
echo ====================================================
echo.
echo  1. Return to the sub-menu
echo  2. Return to the main menu
echo  3. Close the script
echo  4. Open the HP Image Assistant folder (default install location)
echo.
SET /P LR="Enter your choice (1-4): "
IF "%LR%"=="1" GOTO TOOLS
IF "%LR%"=="2" GOTO MENU
IF "%LR%"=="3" GOTO CLOSE
IF "%LR%"=="4" (
    echo Opening the HP Image Assistant folder...
    start "" "C:\SWSetup"
    pause
    GOTO MENU
) else (
    echo Invalid choice. Please try again.
    pause
    GOTO HPUPDATE
)

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
echo Gathering CPU, GPU and RAM information. Please be patient...
timeout /t 4 >nul
cls
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\PS1\Get-CPU_GPU_RAM.ps1"
echo --------------------------------------------------------
echo.
echo.
pause
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
START "" "%windir%\Logs\CBS\CBS.log"
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

:: Generate a battery report
:BATTERY
cls
color 0A
echo Generating a software-based battery report...
echo.
echo Please note:
echo This report is generated from OS data and may differ from the hardware-based battery report offered by some laptops.
echo.
powercfg /batteryreport
pause
echo.
echo Select an option:
echo   1. Open the generated report
echo   2. Return to the previous sub-menu
echo   3. Return to the main menu
echo   4. Exit the script
echo.
set /p K=Enter your choice (1-4): 
if "%K%"=="1" goto BATOPEN
if "%K%"=="2" goto TOOLS
if "%K%"=="3" goto MENU
if "%K%"=="4" goto CLOSE

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
IF %LK%==1 GOTO TOOLS
IF %LK%==2 GOTO MENU
IF %LK%==3 GOTO CLOSE

:CLMGR
cls
color 0A
cleanmgr.exe
pause
echo. 
SET /P LKT=Enter number 1 to return to the previous sub-menu, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %LKT%==1 GOTO TOOLS
IF %LKT%==2 GOTO MENU
IF %LKT%==3 GOTO CLOSE

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

:RESETNETWORK
cls
color 0A
echo.
echo Resetting and flushing the DNS / network stack...
echo.
ipconfig /flushdns
ipconfig /registerdns
ipconfig /release
ipconfig /renew
NETSH winsock reset catalog
NETSH int ipv4 reset reset.log
NETSH int ipv6 reset reset.log
echo.
echo Your Networkstack has been reset, hope it solved your Network / DNS problems!
echo.
pause
GOTO TOOLS

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
echo Downloading Ninite installer silently...
set dest=%temp%\ninite.exe
curl -o "%dest%" "https://ninite.com/7zip-chrome-edge-vlc/ninite.exe"
if exist "%dest%" (
    echo Download complete. Launching installer...
    start "" "%dest%"
) else (
    echo Failed to download the installer.
)
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
echo Running VBS script to retrieve Windows license. Expect a new window to pop up.
cscript //nologo "%~dp0..\VBS\KeyGrabber.vbs"
color 0E
echo.
echo.
cls
SET /p R=If you want to return to the previous sub-menu, enter number 1. To return to the main-menu, enter number 2. To exit the script, enter the number 3. Enter: 
IF %R%==1 GOTO TOOLS
IF %R%==2 GOTO MENU
IF %R%==3 GOTO CLOSE

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
SET /P AC=If yes, enter the number 1, if not enter number 2 to return to the previous sub-menu or enter number 3 to navigate to the repository itself and fetch your own download there. Enter: 
IF %AC%==1 GOTO PCHEALTHGETVERDOWNLOADLINK
IF %AC%==2 GOTO MENU
IF %AC%==3 GOTO PCHEALTHGOTOREPO

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

:PCHEALTHGOTOREPO
cls
color 0A
echo.
echo You will be redirected to the repository to fetch your own download.
echo.
start "" https://github.com/REALSDEALS/pcHealth
echo.
SET /P AP=To return to the sub-menu enter 1, to return to the main menu enter 2 or to close the script enter 3. Enter: 
IF %AP%==1 GOTO PROGRAMS
IF %AP%==2 GOTO MENU
IF %AP%==3 GOTO CLOSE

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
start "" https://www.fosshub.com/HWiNFO.html?dwl=hwi_768.exe
echo.
SET /P AF=To return to the previous sub-menu enter 1, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %AF%==1 GOTO PROGRAMS
IF %AF%==2 GOTO MENU
IF %AF%==3 GOTO CLOSE

:HWMONITORDOWN
cls
color 0A
echo.
echo Are you sure that you want to download the newest version of HWMonitor?
echo.
SET /P AE=If yes, enter the number 1, if not enter number 2 to return to the sub-menu. Enter: 
IF %AE%==1 GOTO HARDMONITORDOWNLOADLINK 
IF %AE%==2 GOTO PROGRAMS

:HARDMONITORDOWNLOADLINK
cls
color 0A
echo.
echo Your download will start now; if not click on 'installer' on the download page!
echo.
winget install --id CPUID.HWMonitor
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
winget install --id Malwarebytes.AdwCleaner
echo.
echo -----------------------------------------------------
echo To start the program, quit this program with CTRL+C and type 'adwcleaner' in a CMD or Powershell terminal. You might need a reboot for this to work.
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
winget install --id CrystalDewWorld.CrystalDiskInfo
echo.
SET /P AJ=To return to the previous sub-menu enter 1, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %AJ%==1 GOTO PROGRAMS
IF %AJ%==2 GOTO MENU
IF %AJ%==3 GOTO CLOSE

:DISKMARKDOWN
cls
color 0A
echo. 
echo Are you sure that you want to download the latest version of CrystalDiskMark?
echo. 
SET /P AK=If yes enter the number 1 to start the download, enter the number 2 to return to the previous sub-menu. Enter: 
IF %AK%==1 GOTO DISKMARKDOWNLOADLINK
IF %AK%==2 GOTO PROGRAMS

:DISKMARKDOWNLOADLINK
cls
color 0A
echo.
echo Your download will start now!
winget install --id CrystalDewWorld.CrystalDiskMark
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
start "" https://prime95.net/download/
echo.
SET /P AN=To return to the previous sub-menu enter 1, enter number 2 to return to the main-menu or enter number 3 to exit the script. Enter: 
IF %AN%==1 GOTO PROGRAMS
IF %AN%==2 GOTO MENU
IF %AN%==3 GOTO CLOSE

:POWERTOYS
cls
color 0A
echo. 
echo Are you sure that you want to install Windows PowerToys?
echo.
SET /P AQ=Enter number 1 if you are sure and want to download Windows PowerToys, enter number 2 if you do not want to install Windows PowerToys; it will redirect you back to the tools menu. 
IF %AQ%==1 GOTO POWERTOYSINSTALL
IF %AQ%==2 GOTO TOOLS

:POWERTOYSINSTALL
cls
color 0A
echo.
echo Your installation of Windows PowerToys will start; keep in mind that it could open a new CMD prompt or PowerShell prompt.
echo. 
winget install --id Microsoft.PowerToys
echo.
echo After the installation, this prompt will close on a keypress. 
pause
GOTO CLOSEACT

:PRERELEASE
cls
color 0A
echo.
echo Are you sure that you want to try out a pre-release? 
echo.
SET /P AO=If yes you could enter number 1 to be redirected to our version page on GitHub, we would like to recieve feedback on your experience with a pre-release build! Because it could help us out, improving our script! You can enter number 2 to return to the main menu or you could enter number 3 to close the script. Enter: 
IF %AO%==1 GOTO GETEARLYRLS
IF %AO%==2 GOTO MENU
IF %AO%==3 GOTO CLOSE

:GETEARLYRLS
cls
color 0A
echo.
echo You will be redirected to the repository and their respective version page.
start "" https://github.com/REALSDEALS/pcHealth/releases
echo.
GOTO MENU

:PCHEALTHPLUSVS
cls
color 0A
echo.
echo You are about to be redirected to the repository of pcHealthPlus.
echo There you can find more information about pcHealthPlus; in short it is a version of pcHealth that is more advanced and has 'more' features.
echo.
start "" https://github.com/REALSDEALS/pcHealthPlus-VS/blob/master/README.md
echo.
SET /P AP=To return to the main menu enter 1 or to close the script enter 2. Enter: 
IF %AP%==1 GOTO MENU
IF %AP%==2 GOTO CLOSE

:CLOSEACT
cls
color 0A
echo.
echo Your requested software has been installed, what would you like to do next?
echo.
SET /P Do you wish to return to the main menu? Enter number 1. If you wish to return to the previous sub menu; enter number 2. If you wish to close this script; enter number 3. Enter: 
IF %AS%==1 GOTO MENU
IF %AS%==2 GOTO TOOLS
IF %AS%==3 GOTO CLOSE

:CLOSE
EXIT /B
