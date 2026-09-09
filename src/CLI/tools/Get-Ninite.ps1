#Requires -Version 7.0
# ============================================================================
# pcHealth -- Get Ninite
# Downloads and launches the Ninite installer (Edge, Chrome, VLC, 7-Zip).
# ============================================================================

$dest = "$env:TEMP\pcHealth-ninite.exe"
$uri  = 'https://ninite.com/7zip-chrome-edge-vlc/ninite.exe'

Write-Host "`nDownloading Ninite installer (Edge, Chrome, VLC, 7-Zip)...`n" -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $uri -OutFile $dest -UseBasicParsing
    Write-Host "[OK] Download complete. Launching installer...`n" -ForegroundColor Green
    if (Test-Path $dest) { Start-Process -FilePath $dest } else { Write-Host "[!!] Installer not found: $dest" -ForegroundColor Red }
} catch {
    Write-Host "[!] Download failed: $($_.Exception.Message)`n" -ForegroundColor Red
}
