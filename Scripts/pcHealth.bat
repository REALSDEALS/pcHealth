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
title pcHealth - Check your PC's Health! //_\\ v1.2.3
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
echo You are now using version 1.2.3
echo.
echo %DATE%, %TIME%
echo.
echo ...........................................................
echo PRESS 1 TO GATHER SYSTEM INFORMATION
echo PRESS 2 TO RUN A SYSTEM SCAN
echo PRESS 3 TO TRY AND REPAIR CORRUPT FILES
echo PRESS 4 TO RUN A SYSTEM SCAN AND START REPAIRING IN ONE GO
echo PRESS 5 TO GENERATE A BATTERY REPORT
echo PRESS 6 TO OPEN WINDOWS UPDATE(S)
echo PRESS 7 TO START A SHORT PING TEST
echo PRESS 8 TO START A CONTINUES PING TEST
echo PRESS 9 TO RE-OPEN THE BATTERY REPORT
echo PRESS 10 TO RE-OPEN THE CBS.log (DISM LOG)
echo PRESS 11 TO GET YOUR NINITE (INCLUDES EDGE, CHROME, VLC AND 7ZIP)
echo PRESS 12 TO CLOSE THIS BATCH FILE
echo ...........................................................
echo.
SET /P A=Type one of the numbers above to run, then press ENTER: 
IF %A%==1 GOTO SYSINFO
IF %A%==2 GOTO SCAN
IF %A%==3 GOTO DISM
IF %A%==4 GOTO SCSM
IF %A%==5 GOTO BATTERY
IF %A%==6 GOTO UPDATE
IF %A%==7 GOTO SHORTPING
IF %A%==8 GOTO CONTINUESPING
IF %A%==9 GOTO BATOPEN
IF %A%==10 GOTO OPENCBSLOG
IF %A%==11 GOTO NINITE
IF %A%==12 GOTO CLOSE

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

:DISM
cls
color C
DISM /online /cleanup-image /checkhealth
DISM /online /cleanup-image /scanhealth
pause
echo.
SET /P D=Enter 1 to start repairing, enter 2 to return to the menu. ENTER: 
IF %D%==1 GOTO DISMRESTORE
IF %D%==2 GOTO MENU

:DISMRESTORE
cls
color C
DISM /online /cleanup-image /restorehealth
pause
echo.
SET /P E=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %E%==1 GOTO MENU
IF %E%==2 GOTO CLOSE

:SCSM
cls
color C
sfc /scannow
pause
echo.
SET /P G=If the scan found corrupt files enter 1 to check the .log, enter 2 to start an attempt to repair the corrupt files, enter 3 to return to the menu. ENTER: 
IF %G%==1 GOTO SCSMOPENLOG
IF %G%==2 GOTO CONTINUE
IF %G%==3 GOTO MENU

:SCSMOPENLOG
cls
color C
start %windir%\explorer.exe "C:\Windows\Logs\CBS\CBS.log"
pause
echo.
SET /P H=Enter 1 to start an attempt to repair the corrupt files, if any are found... Enter 2 to return to the main menu, enter 3 to quit the script. ENTER: 
IF %H%==1 GOTO CONTINUE
IF %H%==2 GOTO MENU
IF %H%==3 GOTO CLOSE

:CONTINUE
cls
color C
DISM /online /cleanup-image /checkhealth
DISM /online /cleanup-image /scanhealth
pause
DISM /online /cleanup-image /restorehealth
pause
echo.
SET /P I=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %I%==1 GOTO MENU
IF %I%==2 GOTO CLOSE

:BATTERY
cls
color C
powercfg /batteryreport
pause
echo.
SET /P J=Enter 1 to open the generated file, enter 2 to return to the menu. ENTER: 
IF %J%==1 GOTO BATOPEN
IF %J%==2 GOTO MENU

:UPDATE
cls
color C
control update
pause
echo.
SET /P K=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %K%==1 GOTO MENU
IF %K%==2 GOTO CLOSE

:SHORTPING
cls
color C
ping 8.8.8.8 
pause
echo.
SET /P L=Enter 1 to return to the menu, enter 2 to start a continues ping test, enter 3 to exit. ENTER: 
IF %L%==1 GOTO MENU
IF %L%==2 GOTO CONTINUESPING
IF %L%==3 GOTO CLOSE

:CONTINUESPING
cls
color C
ping 8.8.8.8 -t -l 256
pause
echo.
SET /P M=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %M%==1 GOTO MENU
IF %M%==2 GOTO CLOSE

:BATOPEN
cls
color C
start %windir%\explorer.exe "C:\battery-report.html"
pause
echo.
SET /P N=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %N%==1 GOTO MENU
IF %N%==2 GOTO CLOSE

:OPENCBSLOG
cls
color C
start %windir%\explorer.exe "C:\Windows\Logs\CBS\CBS.log"
pause
echo.
SET /P O=Enter 1 to return to the main menu, enter 2 to exit. ENTER: 
IF %O%==1 GOTO MENU
IF %O%==2 GOTO CLOSE

:NINITE
cls
color C
start "" https://ninite.com/7zip-chrome-edge-vlc/ninite.exe 
pause
echo.
SET /P Q=Enter 1 to return to the main menu, enter 2 to exit. ENTER: 
IF %Q%==1 GOTO MENU
IF %Q%==2 GOTO CLOSE

:CLOSE
EXIT /B