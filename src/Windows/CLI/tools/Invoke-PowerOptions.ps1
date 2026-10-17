#Requires -Version 7.0
# ============================================================================
# pcHealth -- Shutdown / Reboot / Log Off
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host "  Power Options" -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

Write-Host "  [1]  Log Off"
Write-Host "  [2]  Restart"
Write-Host "  [3]  Shutdown"
Write-Host "  [B]  Cancel`n"

$choice = (Read-Host "  Choice").Trim().ToUpper()

switch ($choice) {
    '1' {
        $ok = (Read-Host "`n  Log off $env:USERNAME? (y/n)").Trim().ToLower()
        if ($ok -eq 'y') {
            # Win32Shutdown flag 0 = Log off. Uses CIM to trigger the normal
            # Windows sign-out flow (respects running apps), unlike logoff.exe.
            $os = Get-CimInstance -ClassName Win32_OperatingSystem
            Invoke-CimMethod -InputObject $os -MethodName Win32Shutdown -Arguments @{ Flags = 0 } | Out-Null
        } else { Write-Host "`n  Cancelled.`n" -ForegroundColor DarkGray }
    }
    '2' {
        $ok = (Read-Host "`n  Restart the PC? (y/n)").Trim().ToLower()
        if ($ok -eq 'y') { Restart-Computer -Force }
        else { Write-Host "`n  Cancelled.`n" -ForegroundColor DarkGray }
    }
    '3' {
        $ok = (Read-Host "`n  Shut down the PC? (y/n)").Trim().ToLower()
        if ($ok -eq 'y') { Stop-Computer -Force }
        else { Write-Host "`n  Cancelled.`n" -ForegroundColor DarkGray }
    }
    'B' { Write-Host "`n  Cancelled.`n" -ForegroundColor DarkGray }
    default { Write-Host "`n  Invalid choice.`n" -ForegroundColor Red }
}
