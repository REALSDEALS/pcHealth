#Requires -Version 7.0
# ============================================================================
# pcHealth -- Disk Optimization
# Opens the built-in Disk Optimization (Defragment and Optimize Drives) GUI.
# ============================================================================

Write-Host "`nOpening Disk Optimization...`n" -ForegroundColor Cyan
# Use full system path to avoid PATH-hijacking on compromised environments.
Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\dfrgui.exe')
Write-Host "[OK] Disk Optimization window opened.`n" -ForegroundColor Green
