#Requires -Version 7.0
# ============================================================================
# pcHealth -- Battery Report
# ============================================================================

$reportPath = "$env:TEMP\pcHealth-battery-report.html"

Write-Host "`nGenerating battery report...`n" -ForegroundColor Cyan
Write-Host "Note: This report is based on OS data and may differ from" -ForegroundColor DarkGray
Write-Host "      hardware-based reports provided by some laptops.`n"  -ForegroundColor DarkGray

# powercfg has no /quiet switch for /batteryreport; passing one makes it fail.
powercfg /batteryreport /output $reportPath | Out-Null

if ($LASTEXITCODE -eq 0 -and (Test-Path $reportPath)) {
    Write-Host "[OK] Report saved to: $reportPath`n" -ForegroundColor Green
    $open = (Read-Host "Open the report now? (y/n)").Trim().ToLower()
    if ($open -eq 'y') { Start-Process -FilePath $reportPath }
} else {
    Write-Host "[!!] powercfg could not create the battery report (exit code $LASTEXITCODE).`n" -ForegroundColor Red
}
