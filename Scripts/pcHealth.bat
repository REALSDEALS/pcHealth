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

echo off
title pcHealth - Check your PC's Health! //\\ v0.1.2-alpha
cd /
color A
cls

:MENU
cls
echo.
echo Thanks for downloading and using pcHealth!
echo Please be sure that you are running this Batch file in Administrator mode.
echo Made by REALSDEALS - Licensed under GNU-3 (You are free to use, but not to change or to remove this line.)
echo You are now using version 0.1.2-alpha
echo.
echo %DATE%, %TIME%
echo.
echo ...........................................................
echo PRESS 1 TO RUN A SYSTEM SCAN
echo PRESS 2 TO TRY AND REPAIR CORRUPT FILES
echo PRESS 3 TO RUN A SYSTEM SCAN AND START REPAIRING IN ONE GO
echo PRESS 4 TO GENERATE A BATTERY REPORT
echo PRESS 5 TO RE-OPEN THE BATTERY REPORT
echo PRESS 6 TO RE-OPEN THE CBS.log (DISM LOG)
echo PRESS 7 TO GET YOUR NINITE (INCLUDES EDGE, CHROME, VLC AND 7ZIP)
echo PRESS 8 TO CLOSE THIS BATCH FILE
echo ...........................................................
echo.
SET /P A=Type one of the numbers above to run, then press ENTER: 
IF %A%==1 GOTO SCAN
IF %A%==2 GOTO DISM
IF %A%==3 GOTO SCSM
IF %A%==4 GOTO BATTERY
IF %A%==5 GOTO BATOPEN
IF %A%==6 GOTO OPENCBSLOG
IF %A%==7 GOTO NINITE
IF %A%==8 GOTO CLOSE

:SCAN
sfc /scannow
pause
echo.
SET /P B=If the scan found corrupt files enter 1 to check the .log, enter 2 when you want to return to the menu. ENTER: 
IF %B%==1 GOTO OPENCBSLOG
IF %B%==2 GOTO MENU

:DISM
DISM /online /cleanup-image /checkhealth
DISM /online /cleanup-image /scanhealth
pause
echo.
SET /P C=Enter 1 to start repairing, enter 2 to return to the menu. ENTER: 
IF %C%==1 GOTO DISMRESTORE
IF %C%==2 GOTO MENU

:DISMRESTORE
DISM /online /cleanup-image /restorehealth
pause
echo.
SET /P D=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %D%==1 GOTO MENU
IF %D%==2 GOTO CLOSE

:SCSM
sfc /scannow
pause
echo.
SET /P E=If the scan found corrupt files enter 1 to check the .log, enter 2 to start an attempt to repair the corrupt files, enter 3 to return to the menu. ENTER: 
IF %E%==1 GOTO SCSMOPENLOG
IF %E%==2 GOTO CONTINUE
IF %E%==3 GOTO MENU

:SCSMOPENLOG
start %windir%\explorer.exe "C:\Windows\Logs\CBS\CBS.log"
pause
echo.
SET /P G=Enter 1 to start an attempt to repair the corrupt files, if any are found... Enter 2 to return to the main menu, enter 3 to quit the script. ENTER: 
IF %G%==1 GOTO CONTINUE
IF %G%==2 GOTO MENU
IF %G%==3 GOTO CLOSE

:CONTINUE
DISM /online /cleanup-image /checkhealth
DISM /online /cleanup-image /scanhealth
pause
DISM /online /cleanup-image /restorehealth
pause
echo.
SET /P H=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %H%==1 GOTO MENU
IF %H%==2 GOTO CLOSE

:BATTERY
powercfg /batteryreport
pause
echo.
SET /P I=Enter 1 to open the generated file, enter 2 to return to the menu. ENTER: 
IF %I%==1 GOTO BATOPEN
IF %I%==2 GOTO MENU

:BATOPEN
start %windir%\explorer.exe "C:\battery-report.html"
pause
echo.
SET /P J=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %J%==1 GOTO MENU
IF %J%==2 GOTO CLOSE

:OPENCBSLOG
start %windir%\explorer.exe "C:\Windows\Logs\CBS\CBS.log"
pause
echo.
SET /P K=Enter 1 to return to the main menu, enter 2 to exit. ENTER: 
IF %K%==1 GOTO MENU
IF %K%==2 GOTO CLOSE

:NINITE
start "" https://ninite.com/7zip-chrome-edge-vlc/ninite.exe 
pause
echo.
SET /P L=Enter 1 to return to the main menu, enter 2 to exit. ENTER: 
IF %L%==1 GOTO MENU
IF %L%==2 GOTO CLOSE

:CLOSE
EXIT /B