Clear-Host
Write-Host ""
Write-Host "Thanks for downloading and using pcHealth!"
Write-Host ""
Write-Host "This PowerShell script is made by REALSDEALS" 
Write-Host "Licensed under GNU-3 (You are free to use, but not to change or to remove this line.)"
Write-Host ""
Write-Host "You are now using PowerShell version v0.1.0-alpha"
Write-Host ""

function Show-Menu {
    param (
        [string]$Title = 'pcHealth | v0.1.0-alpha'
    )
    Write-Host ""
    Write-Host "================ $Title ================"
    Write-Host ""
    Write-Host "1: PRESS '1' TO GATHER SYSTEM INFORMATION"
    Write-Host "2: PRESS '2' TO CHECK WHICH CPU AND GPU ARE IN THE SYSTEM"
    Write-Host "3: PRESS '3' RUN A SYSTEM SCAN"
    Write-Host "4: PRESS '4' TO TRY AND REPAIR CORRUPT FILES"
    Write-Host "5: PRESS '5' TO RUN A SYSTEM SCAN AND START REPAIRING IN ONE GO"
    Write-Host "6: PRESS '6' TO GENERATE A BATTERY REPORT"
    Write-Host "7: PRESS '7' TO OPEN WINDOWS UPDATE(S)"
    Write-Host "8: PRESS '8' TO START A SHORT PING TEST"
    Write-Host "9: PRESS '9' TO START A CONTINUES PING TEST"
    Write-Host "10: PRESS '10' TO RE-OPEN THE BATTERY REPORT"
    Write-Host "11: PRESS '11' TO RE-OPEN THE CBS.log (DISM LOG)"
    Write-Host "12: PRESS '12' TO GET YOUR NINITE (INCLUDES EDGE, CHROME, VLC AND 7ZIP)"
    Write-Host "13: PRESS '13' TO RESTART OR SHUTDOWN YOUR PC/LAPTOP"
    Write-Host "14: PRESS 'Q' TO CLOSE THIS POWERSHELL SCRIPT"
    Write-Host ""
}
do {
    Show-Menu
    $selection = Read-Host "Enter the number of the instance that you want to run."
    switch ($selection) {
        '1' {
            'Sorry, this option has no function yet.'
            pause 
        } '2' {
            'Sorry, this option has no function yet.'
            pause
        } '3' {
            'Sorry, this option has no function yet.'
            pause
        } '4' {
            'Sorry, this option has no function yet.'
            pause
        } '5' {
            'Sorry, this option has no function yet.'
            pause
        } '6' {
            'Sorry, this option has no function yet.'
            pause
        } '7' {
            'Sorry, this option has no function yet.'
            pause
        } '8' {
            'Sorry, this option has no function yet.'
            pause
        } '9' {
            'Sorry, this option has no function yet.'
            pause
        } '10' {
            'Sorry, this option has no function yet.'
            pause
        } '11' {
            'Sorry, this option has no function yet.'
            pause
        } '12' {
            'Sorry, this option has no function yet.'
            pause
        } '13' {
            'Sorry, this option has no function yet.'
            pause
        }
    }
}
until ($selection -eq 'q')
Pause
