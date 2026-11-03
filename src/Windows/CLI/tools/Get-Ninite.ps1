#Requires -Version 7.0
# ============================================================================
# pcHealth -- Get Ninite
# Downloads and launches the Ninite installer (Edge, Chrome, VLC, 7-Zip).
# ============================================================================

$dest = Join-Path $env:TEMP 'pcHealth-ninite.exe'
$uri  = 'https://ninite.com/7zip-chrome-edge-vlc/ninite.exe'

Write-Host "`nDownloading Ninite installer (Edge, Chrome, VLC, 7-Zip)...`n" -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $uri -OutFile $dest -UseBasicParsing
} catch {
    Write-Host "[!] Download failed: $($_.Exception.Message)`n" -ForegroundColor Red
    return
}

# The installer runs with this session's administrator rights, so only start
# it when Windows confirms it is unmodified and signed by Ninite's publisher.
$sig = Get-AuthenticodeSignature -LiteralPath $dest -ErrorAction SilentlyContinue
if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Secure By Design Inc\.') {
    Write-Host "[!!] The download is not signed by Ninite (signature: $($sig.Status))." -ForegroundColor Red
    Write-Host "     It was not started. File: $dest`n" -ForegroundColor Yellow
    return
}

Write-Host "[OK] Download complete and signed by Ninite. Launching installer...`n" -ForegroundColor Green
Start-Process -FilePath $dest
