echo off
title pcHealth - Check your PC's Health!
cd /
color B
cls
echo.
echo Thanks for downloading and using pcHealth!
echo Please be sure that you are running this Batch file in Administrator mode.
echo Made by REALSDEALS - Licensed under GNU-3 (You are free to use, but not to change or to remove this line.)
echo.
echo %DATE%, %TIME%
:MENU
echo.
echo ...........................................................
echo PRESS 1 TO RUN A SYSTEM SCAN
echo PRESS 2 TO TRY AND REPAIR CORRUPT FILES
echo PRESS 3 TO RUN A SYSTEM SCAN AND START REPAIRING IN ONE GO
echo PRESS 4 TO GENERATED A BATTERY REPORT
echo PRESS 5 TO RE-OPEN THE BATTERY REPORT
echo PRESS 6 TO CLOSE THIS BATCH FILE
echo ...........................................................
echo.
SET /P A=Type 1, 2, 3, 4, 5 or 6 then press ENTER: 
IF %A%==1 GOTO SCAN
IF %A%==2 GOTO DISM
IF %A%==3 GOTO SCSM
IF %A%==4 GOTO BATTERY
IF %A%==5 GOTO BATOPEN
IF %A%==6 GOTO CLOSE
:SCAN
sfc /scannow
pause
echo.
SET /P B=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %B%==1 GOTO MENU
IF %B%==2 GOTO CLOSE
:BATTERY
powercfg /batteryreport
pause
SET /P G=Enter 1 to open the generated file, enter 2 to return to the menu. ENTER: 
IF %G%==1 GOTO BATOPEN
IF %G%==2 GOTO MENU
:BATOPEN
start %windir%\explorer.exe "C:\battery-report.html"
pause
echo.
SET /P C=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %C%==1 GOTO MENU
IF %C%==2 GOTO CLOSE
:DISM
DISM /online /cleanup-image /checkhealth
DISM /online /cleanup-image /scanhealth
pause
DISM /online /cleanup-image /restorehealth
pause
echo.
SET /P D=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %D%==1 GOTO MENU
IF %D%==2 GOTO CLOSE
:SCSM
sfc /scannow
pause
DISM /online /cleanup-image /checkhealth
DISM /online /cleanup-image /scanhealth
pause
DISM /online /cleanup-image /restorehealth
pause
echo.
SET /P E=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %E%==1 GOTO MENU
IF %E%==2 GOTO CLOSE
:CLOSE
EXIT /B