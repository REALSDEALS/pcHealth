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
echo PRESS 3 TO CLOSE THIS BATCH FILE
echo ........................................
echo.
SET /P M=Type 1, 2, or 3 then press ENTER:
IF %M%==1 GOTO SCAN
IF %M%==2 GOTO DISM
IF %M%==3 GOTO CLOSE
:SCAN
sfc /scannow
pause
:DISM
DISM /online /cleanup-image /checkhealth
DISM /online /cleanup-image /scanhealth
DISM /online /cleanup-image /restorehealth
pause
:CLOSE
EXIT /B