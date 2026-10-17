#Requires -Version 7.0
# ============================================================================
# pcHealth -- Restart Audio Drivers
# ============================================================================

Write-Host "`nRestarting audio services...`n" -ForegroundColor Cyan

try {
    Write-Host "[>>] Stopping AudioEndpointBuilder..." -ForegroundColor Yellow
    Stop-Service -Name 'AudioEndpointBuilder' -Force -ErrorAction Stop
    Write-Host "[>>] Stopping Audiosrv..." -ForegroundColor Yellow
    Stop-Service -Name 'Audiosrv' -Force -ErrorAction Stop

    Start-Sleep -Seconds 1

    Write-Host "[>>] Starting AudioEndpointBuilder..." -ForegroundColor Yellow
    Start-Service -Name 'AudioEndpointBuilder' -ErrorAction Stop
    Write-Host "[>>] Starting Audiosrv..." -ForegroundColor Yellow
    Start-Service -Name 'Audiosrv' -ErrorAction Stop

    Write-Host "`n[OK] Audio services restarted. Test your audio now.`n" -ForegroundColor Green
} catch {
    Write-Host "`n[!!] Failed to restart audio services: $_`n" -ForegroundColor Red
}
