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
echo PRESS 4 TO GENERATE A BATTERY REPORT
echo PRESS 5 TO RE-OPEN THE BATTERY REPORT
echo PRESS 6 TO RE-OPEN THE CBS.log (DISM LOG)
echo PRESS 7 TO CLOSE THIS BATCH FILE
echo ...........................................................
echo.
SET /P A=Type one of the numbers above to run, then press ENTER: 
IF %A%==1 GOTO SCAN
IF %A%==2 GOTO DISM
IF %A%==3 GOTO SCSM
IF %A%==4 GOTO BATTERY
IF %A%==5 GOTO BATOPEN
IF %A%==6 GOTO OPENCBSLOG
IF %A%==7 GOTO CLOSE
:SCAN
sfc /scannow
pause
echo.
SET /P K=If the scan found corrupt files enter 1 to check the .log, enter 2 when you want to return to the menu. ENTER: 
IF %K%==1 GOTO OPENCBSLOG
IF %K%==2 GOTO MENU
:BATTERY
powercfg /batteryreport
pause
echo.
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
echo.
SET /P H=Enter 1 to open up the generated CBS.log, enter 2 to skip and try to repair the image. ENTER: 
IF %H%==1 GOTO CBSLOGGER
IF %H%==2 GOTO DISMRESTORE
:CBSLOGGER
start %windir%\explorer.exe "C:\Windows\Logs\CBS\CBS.log"
pause
echo.
SET /P I=Enter 1 to continue the restore process, enter 2 to return to the menu or enter 3 to exit. ENTER: 
IF %I%==1 GOTO DISMRESTORE
IF %I%==2 GOTO MENU
IF %I%==3 GOTO CLOSE
:DISMRESTORE
DISM /online /cleanup-image /restorehealth
pause
echo.
SET /P D=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %D%==1 GOTO MENU
IF %D%==2 GOTO CLOSE
:OPENCBSLOG
start %windir%\explorer.exe "C:\Windows\Logs\CBS\CBS.log"
pause
echo.
SET /P J=Enter 1 to return to the main menu, enter 2 to exit. ENTER: 
IF %J%==1 GOTO MENU
IF %J%==2 GOTO CLOSE
:SCSM
sfc /scannow
pause
echo.
SET /P L=If the scan found corrupt files enter 1 to check the .log, enter 2 to start an attempt to repair the corrupt files. ENTER: 
IF %L%==1 GOTO SCSMOPENLOG
IF %L%==2 GOTO CONTINUE
:CONTINUE
DISM /online /cleanup-image /checkhealth
DISM /online /cleanup-image /scanhealth
pause
DISM /online /cleanup-image /restorehealth
pause
echo.
SET /P E=Enter 1 to return to the menu, enter 2 to exit. ENTER: 
IF %E%==1 GOTO MENU
IF %E%==2 GOTO CLOSE
:SCSMOPENLOG
start %windir%\explorer.exe "C:\Windows\Logs\CBS\CBS.log"
pause
echo.
SET /P J=Enter 1 to start an attempt to repair the corrupt files, if any are found... Enter 2 to return to the main menu, enter 3 to quit the script. ENTER: 
IF %J%==1 GOTO CONTINUE
IF %J%==2 GOTO MENU
IF %J%==3 GOTO CLOSE
:CLOSE
EXIT /B