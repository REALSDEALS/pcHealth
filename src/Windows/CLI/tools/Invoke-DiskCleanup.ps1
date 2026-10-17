#Requires -Version 7.0
# ============================================================================
# pcHealth -- Disk Cleanup
# Opens the built-in Disk Cleanup utility.
# ============================================================================

Write-Host "`nOpening Disk Cleanup...`n" -ForegroundColor Cyan
# Use full system path to avoid PATH-hijacking on compromised environments.
Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\cleanmgr.exe')
Write-Host "[OK] Disk Cleanup window opened.`n" -ForegroundColor Green
