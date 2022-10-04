Clear-Host
Write-Host ""
Write-Host "Thanks for downloading and using pcHealth!"
Write-Host ""
Write-Host "This PowerShell script is made by REALSDEALS" 
Write-Host "Licensed under GNU-3 (You are free to use, but not to change or to remove this line.)"
Write-Host ""
Write-Host "You are now using PowerShell version v0.2.1-alpha"
Write-Host ""
cd c:/

function isAdmin {
    #Check if the user runs this script as Administrator.
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        # Relaunch as an elevated process:
        Start-Process powershell.exe "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
        exit
    }
    # Now running elevated so launch the script:
    & "c:\long path name\script name.ps1" "Long Argument 1" "Long Argument 2"
}

function Show-Menu {
    param (
        [string]$Title = 'pcHealth | v0.2.1-alpha'
    )
    Clear-Host
    Write-Host ""
    Write-Host "================ $Title ================"
    Write-Host ""
    Write-Host "1: ENTER '1' TO GATHER SYSTEM INFORMATION"
    Write-Host "2: ENTER '2' TO CHECK WHICH CPU AND GPU ARE IN THE SYSTEM"
    Write-Host "3: ENTER '3' RUN A SYSTEM SCAN"
    Write-Host "4: ENTER '4' TO TRY AND REPAIR CORRUPT FILES"
    Write-Host "5: ENTER '5' TO RUN A SYSTEM SCAN AND START REPAIRING IN ONE GO"
    Write-Host "6: ENTER '6' TO GENERATE A BATTERY REPORT"
    Write-Host "7: ENTER '7' TO OPEN WINDOWS UPDATE(S)"
    Write-Host "8: ENTER '8' TO START A SHORT PING TEST"
    Write-Host "9: ENTER '9' TO START A CONTINUES PING TEST"
    Write-Host "10: ENTER '10' TO RE-OPEN THE BATTERY REPORT"
    Write-Host "11: ENTER '11' TO RE-OPEN THE CBS.log (DISM LOG)"
    Write-Host "12: ENTER '12' TO GET YOUR NINITE (INCLUDES EDGE, CHROME, VLC AND 7ZIP)"
    Write-Host "13: ENTER '13' TO RESTART OR SHUTDOWN YOUR LAPTOP/PC"
    Write-Host "14: ENTER '14' TO SHUTDOWN YOUR LAPTOP/PC"
    Write-Host "15: ENTER 'Q' TO CLOSE THIS POWERSHELL SCRIPT"
    Write-Host ""
}
do {
    Show-Menu
    $selection = Read-Host "Enter the number of the instance that you want to run."
    switch ($selection) {
        '1' {
            Write-Host ""
            Write-Host "Computer information will be generated..."
            Get-ComputerInfo
            Write-Host ""
            pause 
        } '2' {
            Write-Host ""
            Write-Host "Your CPU information:"
            Get-WmiObject -Class Win32_Processor -ComputerName $env:COMPUTERNAME
            Write-Host ""
            Write-Host "Your GPU information:"
            Get-WmiObject win32_VideoController | Format-List Name
            Write-Host ""
            pause
        } '3' {
            Write-Host ""
            sfc /scannow
            Write-Host ""
            pause
        } '4' {
            'Sorry, this option has no function yet.'
            pause
        } '5' {
            'Sorry, this option has no function yet.'
            pause
        } '6' {
            Write-Host ""
            powercfg /batteryreport
            start "C:\battery-report.html"
            Write-Host ""
            pause
        } '7' {
            Write-Host ""
            control update
            Write-Host ""
            pause
        } '8' {
            Write-Host ""
            ping 8.8.8.8 
            Write-Host ""
            pause
        } '9' {
            Write-Host ""
            ping 8.8.8.8 -t -l 256
            Write-Host ""
            pause
        } '10' {
            'Sorry, this option has no function yet.'
            pause
        } '11' {
            'Sorry, this option has no function yet.'
            pause
        } '12' {
            Write-Host ""
            start explorer.exe "https://ninite.com/7zip-chrome-edge-vlc/ninite.exe"
            pause
        } '13' {
            Write-Host ""
            Write-Host "Your system will be restarted."
            Restart-Computer
            Write-Host ""
            pause
        } '14' {
            Write-Host ""
            Write-Host "pc-Health.ps will be terminated."
            Write-Host ""
            pause
        }
    }
}
until ($selection -eq 'q')
Pause
