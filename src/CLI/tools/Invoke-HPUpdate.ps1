#Requires -Version 7.0
# ============================================================================
# pcHealth -- Update HP Drivers
# Installs HP Image Assistant which detects and updates HP-specific drivers.
# ============================================================================

# Warn if this does not appear to be an HP device so users don't install
# unnecessary software on non-HP machines.
$manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).Manufacturer
if ($manufacturer -and $manufacturer -notmatch 'HP|Hewlett') {
    Write-Host "`n[!] This machine appears to be manufactured by '$manufacturer', not HP." -ForegroundColor Yellow
    Write-Host "    HP Image Assistant is only useful on HP devices." -ForegroundColor Yellow
    $cont = (Read-Host "    Continue anyway? (y/n)").Trim().ToLower()
    if ($cont -ne 'y') {
        Write-Host "`n  Cancelled.`n" -ForegroundColor DarkGray
        return
    }
}

Write-Host "`nInstalling HP Image Assistant via winget...`n" -ForegroundColor Cyan

winget install --source winget --id HP.ImageAssistant --accept-source-agreements --accept-package-agreements

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[OK] HP Image Assistant installed. Launch it to update HP drivers.`n" -ForegroundColor Green
} else {
    Write-Host "`n[!!] Installation returned exit code $LASTEXITCODE.`n" -ForegroundColor Red
}
