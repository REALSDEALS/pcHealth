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
title pcHealth - Check your PC's Health! //_\\ v1.3.3-beta
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
echo You are now using version 1.3.3-beta
echo.
echo %DATE%, %TIME%
echo.
echo ...........................................................
echo PRESS 1 TO GATHER SYSTEM INFORMATION
echo PRESS 2 TO CHECK WHICH CPU AND GPU ARE IN THE SYSTEM
echo PRESS 3 TO RUN A SYSTEM SCAN
echo PRESS 4 TO TRY AND REPAIR CORRUPT FILES
echo PRESS 5 TO RUN A SYSTEM SCAN AND START REPAIRING IN ONE GO
echo PRESS 6 TO GENERATE A BATTERY REPORT
echo PRESS 7 TO OPEN WINDOWS UPDATE(S)
echo PRESS 8 TO START A SHORT PING TEST
echo PRESS 9 TO START A CONTINUES PING TEST
echo PRESS 10 TO RE-OPEN THE BATTERY REPORT
echo PRESS 11 TO RE-OPEN THE CBS.log (DISM LOG)
echo PRESS 12 TO GET YOUR NINITE (INCLUDES EDGE, CHROME, VLC AND 7ZIP)
echo PRESS 13 TO RESTART OR SHUTDOWN YOUR PC/LAPTOP
echo PRESS 14 TO CLOSE THIS BATCH FILE
echo ...........................................................
echo.
SET /P A=Type one of the numbers above to run, then press ENTER: 
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
IF %A%==13 GOTO RESHUT
IF %A%==14 GOTO CLOSE

:SYSINFO
cls
color C
systeminfo
pause
echo.
SET /P B=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %B%==1 GOTO MENU
IF %B%==2 GOTO CLOSE

:SCAN
cls
color C
sfc /scannow
pause
echo.
SET /P C=If the scan found corrupt files enter 1 to check the .log, enter 2 when you want to return to the menu. ENTER: 
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
SET /P D=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %D%==1 GOTO MENU
IF %D%==2 GOTO CLOSE

:DISM
cls
color C
DISM /online /cleanup-image /checkhealth
DISM /online /cleanup-image /scanhealth
pause
echo.
SET /P E=Enter 1 to start repairing, enter 2 to return to the menu. ENTER: 
IF %E%==1 GOTO DISMRESTORE
IF %E%==2 GOTO MENU

:DISMRESTORE
cls
color C
DISM /online /cleanup-image /restorehealth
pause
echo.
SET /P G=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %G%==1 GOTO MENU
IF %G%==2 GOTO CLOSE

:SCSM
cls
color C
sfc /scannow
pause
echo.
SET /P H=If the scan found corrupt files enter 1 to check the .log, enter 2 to start an attempt to repair the corrupt files, enter 3 to return to the menu. ENTER: 
IF %H%==1 GOTO SCSMOPENLOG
IF %H%==2 GOTO CONTINUE
IF %H%==3 GOTO MENU

:SCSMOPENLOG
cls
color C
start %windir%\explorer.exe "C:\Windows\Logs\CBS\CBS.log"
pause
echo.
SET /P I=Enter 1 to start an attempt to repair the corrupt files, if any are found... Enter 2 to return to the main menu, enter 3 to quit the script. ENTER: 
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
SET /P J=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %J%==1 GOTO MENU
IF %J%==2 GOTO CLOSE

:BATTERY
cls
color C
powercfg /batteryreport
pause
echo.
SET /P K=Enter 1 to open the generated file, enter 2 to return to the menu. ENTER: 
IF %K%==1 GOTO BATOPEN
IF %K%==2 GOTO MENU

:UPDATE
cls
color C
control update
pause
echo.
SET /P L=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %L%==1 GOTO MENU
IF %L%==2 GOTO CLOSE

:SHORTPING
cls
color C
ping 8.8.8.8 
pause
echo.
SET /P M=Enter 1 to return to the menu, enter 2 to start a continues ping test, enter 3 to exit. ENTER: 
IF %M%==1 GOTO MENU
IF %M%==2 GOTO CONTINUESPING
IF %M%==3 GOTO CLOSE

:CONTINUESPING
cls
color C
ping 8.8.8.8 -t -l 256
pause
echo.
SET /P N=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %N%==1 GOTO MENU
IF %N%==2 GOTO CLOSE

:BATOPEN
cls
color C
start %windir%\explorer.exe "C:\battery-report.html"
pause
echo.
SET /P O=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %O%==1 GOTO MENU
IF %O%==2 GOTO CLOSE

:OPENCBSLOG
cls
color C
start %windir%\explorer.exe "C:\Windows\Logs\CBS\CBS.log"
pause
echo.
SET /P P=Enter 1 to return to the main menu, enter 2 to exit. ENTER: 
IF %P%==1 GOTO MENU
IF %P%==2 GOTO CLOSE

:NINITE
cls
color C
start "" https://ninite.com/7zip-chrome-edge-vlc/ninite.exe 
pause
echo.
SET /P Q=Enter 1 to return to the main menu, enter 2 to exit. ENTER: 
IF %Q%==1 GOTO MENU
IF %Q%==2 GOTO CLOSE

:RESHUT
cls
color C
echo. 
SET /P R=If you want to log off from your PC/Laptop press 1, to restart press 2, to shutdown press 3 and to return to the main menu press 4. ENTER: 
IF %R%==1 GOTO LOGOFF1
IF %R%==2 GOTO RESTART2
IF %R%==3 GOTO SHUTDOWN3
IF %R%==4 GOTO CLOSE

:LOGOFF1
cls
color C 
echo. 
SET /P S=Are you sure that you want to log off your PC? Press 1, Press 2 if you want to return to the menu. ENTER: 
IF %S%==1 GOTO LOGOFFCONFIRM1
IF %S%==2 GOTO MENU 

:LOGOFFCONFIRM1
cls
color C  
shutdown /l 
EXIT /B

:RESTART2
cls
color C
echo.
SET /P T=Are you sure that you want to restart your PC? Press 1, to do so. Press 2 to return to the main menu. ENTER: 
IF %T%==1 GOTO RESTARTCONFIRM2
IF %T%==2 GOTO MENU

:RESTARTCONFIRM2
cls
color C 
shutdown /r
EXIT /B

:SHUTDOWN3
cls
color C
echo. 
SET /P U=Are you sure that you want to shutdown your PC? Press 1, to continue. Enter 2 to return to the main menu. ENTER: 
IF %U%==1 GOTO SHUTDOWNCONFIRM3
IF %U%==2 GOTO MENU

:SHUTDOWNCONFIRM3
cls
color C
shutdown /s
EXIT /B

:CLOSE
EXIT /B