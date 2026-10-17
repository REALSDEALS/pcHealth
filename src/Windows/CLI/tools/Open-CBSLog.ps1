#Requires -Version 7.0
# ============================================================================
# pcHealth -- Open CBS Log
# ============================================================================

$logPath = "$env:SystemRoot\Logs\CBS\CBS.log"

if (Test-Path $logPath) {
    Write-Host "`nOpening CBS log...`n" -ForegroundColor Cyan
    Start-Process notepad.exe -ArgumentList $logPath
    Write-Host "[OK] CBS.log opened in Notepad.`n" -ForegroundColor Green
} else {
    Write-Host "`n[!] CBS.log not found at: $logPath`n" -ForegroundColor Yellow
}
