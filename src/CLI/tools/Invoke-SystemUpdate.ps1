#Requires -Version 7.0
# ============================================================================
# pcHealth -- Update System Programs
# Upgrades all installed winget packages.
# ============================================================================

Write-Host "`nDetecting updatable packages...`n" -ForegroundColor Cyan

winget upgrade
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[!!] winget exited with code $LASTEXITCODE -- winget may be broken or unavailable.`n" -ForegroundColor Red
    return
}

Write-Host ''
$confirm = (Read-Host "Proceed with updating all packages? (y/n)").Trim().ToLower()

if ($confirm -eq 'y') {
    Write-Host "`nUpdating all packages...`n" -ForegroundColor Yellow
    winget upgrade --all --accept-source-agreements --accept-package-agreements --silent
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[!!] winget upgrade exited with code $LASTEXITCODE.`n" -ForegroundColor Red
    } else {
        Write-Host "`n[OK] Update complete.`n" -ForegroundColor Green
    }
} else {
    Write-Host "`nUpdate cancelled.`n" -ForegroundColor DarkGray
}
