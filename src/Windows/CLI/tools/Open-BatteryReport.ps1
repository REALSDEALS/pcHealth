#Requires -Version 7.0
# ============================================================================
# pcHealth -- Open Battery Report
# ============================================================================

$reportPath = "$env:TEMP\pcHealth-battery-report.html"

if (Test-Path $reportPath) {
    Write-Host "`nOpening battery report...`n" -ForegroundColor Cyan
    Start-Process -FilePath $reportPath
    Write-Host "[OK] Report opened: $reportPath`n" -ForegroundColor Green
} else {
    Write-Host "`n[!] No battery report found." -ForegroundColor Yellow
    Write-Host "    Generate one first via Tools > Battery Report.`n" -ForegroundColor DarkGray
}
