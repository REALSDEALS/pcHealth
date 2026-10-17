#Requires -Version 7.0
# ============================================================================
# pcHealth -- Repair Winget
# Credits: @asheroto -- https://github.com/asheroto/winget-install
# ============================================================================

Write-Host "`n  Repairing winget using the winget-install module" -ForegroundColor Cyan
Write-Host "  Credits: @asheroto -- https://github.com/asheroto/winget-install`n" -ForegroundColor DarkGray

Write-Host "[>>] Installing winget-install script from PSGallery..." -ForegroundColor Yellow
try {
    Install-Script -Name winget-install -Force -Scope CurrentUser -ErrorAction Stop
    Write-Host "[OK] Script installed." -ForegroundColor Green
} catch {
    Write-Host "[!!] Failed to install script: $_" -ForegroundColor Red
    return
}

Write-Host "[>>] Running winget-install (this may take a moment)..." -ForegroundColor Yellow
# winget-install calls exit internally -- run in a child process to keep our session alive.
$installed  = Get-InstalledScript winget-install -ErrorAction SilentlyContinue
$scriptArgs = if ($installed) {
    $scriptFile = Join-Path $installed.InstalledLocation 'winget-install.ps1'
    "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFile`" -Force"
} else {
    '-NoProfile -ExecutionPolicy Bypass -Command winget-install -Force'
}
$result = Start-Process pwsh -ArgumentList $scriptArgs -Wait -PassThru
if ($result.ExitCode -eq 0) {
    Write-Host "[OK] Winget repair complete." -ForegroundColor Green
} else {
    Write-Host "[!!] Repair exited with code $($result.ExitCode)." -ForegroundColor Red
}

Write-Host ''
