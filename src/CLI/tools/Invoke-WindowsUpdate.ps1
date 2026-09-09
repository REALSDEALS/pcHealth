#Requires -Version 7.0
# ============================================================================
# pcHealth -- Windows Update
# Opens the Windows Update settings page.
# ============================================================================

Write-Host "`nOpening Windows Update settings...`n" -ForegroundColor Cyan
Start-Process 'ms-settings:windowsupdate'
Write-Host "[OK] Windows Update settings opened in the Settings app.`n" -ForegroundColor Green
