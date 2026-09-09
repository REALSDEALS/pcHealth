#Requires -Version 7.0
# ============================================================================
# pcHealth -- Network Reset (Linux)
# Restarts NetworkManager (or systemd-networkd) and flushes the DNS cache.
# Note: this briefly drops the network connection.
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host '  Network Reset' -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

if (-not (Get-Command systemctl -ErrorAction SilentlyContinue)) {
    Write-Host "[!!] systemctl not found. This system may not use systemd.`n" -ForegroundColor Red
    return
}

function Invoke-Step {
    param([string]$Label, [scriptblock]$Action)
    Write-Host "[>>] $Label" -ForegroundColor Yellow
    $out = & $Action 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Done.`n" -ForegroundColor Green
    } else {
        Write-Host "[!!] Exit code $LASTEXITCODE.`n" -ForegroundColor Red
        if ($out) { $out | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray } }
    }
}

Write-Host "  Note: the network connection will drop briefly.`n" -ForegroundColor DarkGray

$nmActive = (Get-PcCommandOutput 'systemctl' @('is-active', 'NetworkManager')) -eq 'active'

if ($nmActive -or (Get-Command nmcli -ErrorAction SilentlyContinue)) {
    Invoke-Step 'Restarting NetworkManager...' { systemctl restart NetworkManager }
} else {
    Invoke-Step 'Restarting systemd-networkd...' { systemctl restart systemd-networkd }
}

if (Get-Command resolvectl -ErrorAction SilentlyContinue) {
    Invoke-Step 'Flushing DNS cache...' { resolvectl flush-caches }
} elseif (Get-Command systemd-resolve -ErrorAction SilentlyContinue) {
    Invoke-Step 'Flushing DNS cache...' { systemd-resolve --flush-caches }
}

Write-Host "  Network reset complete.`n" -ForegroundColor Green
