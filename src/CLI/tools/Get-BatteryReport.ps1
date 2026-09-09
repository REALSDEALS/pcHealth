#Requires -Version 7.0
# ============================================================================
# pcHealth -- Battery Report
# ============================================================================

$reportPath = "$env:TEMP\pcHealth-battery-report.html"

Write-Host "`nGenerating battery report...`n" -ForegroundColor Cyan
Write-Host "Note: This report is based on OS data and may differ from" -ForegroundColor DarkGray
Write-Host "      hardware-based reports provided by some laptops.`n"  -ForegroundColor DarkGray

powercfg /batteryreport /output $reportPath /quiet

    if ($LASTEXITCODE -eq 0 -and (Test-Path $reportPath)) {
    Write-Host "[OK] Report saved to: $reportPath`n" -ForegroundColor Green
    $open = (Read-Host "Open the report now? (y/n)").Trim().ToLower()
    if ($open -eq 'y') { Start-Process -FilePath $reportPath }
} else {
    Write-Host "[!] No battery detected on this system. Battery report is not available.`n" -ForegroundColor Yellow
}
