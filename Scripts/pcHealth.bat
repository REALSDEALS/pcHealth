echo off
cd /
color 6
cls
echo Thanks for downloading and using pcHealth!
echo Please be sure that you are running this Batch file in Administrator mode.
echo Made by REALSDEALS - Licensed under GNU-3 (You are free to use, but not to change or to remove this line.)
:MENU
echo.
echo ........................................
echo PRESS 1 TO RUN A SYSTEM SCAN
echo PRESS 2 TO TRY AND REPAIR CORRUPT FILES
echo PRESS 3 TO GET A BATTERY REPORT
echo PRESS 4 TO CLOSE THIS BATCH FILE
echo ........................................
echo.
SET /P M=Type 1, 2, 3, or 4 then press ENTER:
IF %M%==1 GOTO SCAN
IF %M%==2 GOTO DISM
IF %M%==3 GOTO BATTERY
IF %M%==4 GOTO CLOSE
:SCAN
sfc /scannow
GOTO MENU
:BATTERY
powercfg /batteryreport
GOTO MENU
:DISM
DISM /online /cleanup-image /checkhealth
pause
DISM /online /cleanup-image /scanhealth
pause
DISM /online /cleanup-image /restorehealth
pause
GOTO MENU
:CLOSE
EXIT /B