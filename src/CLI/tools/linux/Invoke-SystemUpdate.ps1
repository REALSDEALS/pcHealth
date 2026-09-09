#Requires -Version 7.0
# ============================================================================
# pcHealth -- Update all packages (Linux)
# Distro-native counterpart to the winget update on Windows. Unlike Topgrade
# this needs nothing installed beyond the package manager the distro ships.
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host '  Update all packages' -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

$pm = Get-PcPackageManager
if (-not $pm) {
    Write-Host "[!!] No supported package manager found (apt/dnf/pacman/zypper).`n" -ForegroundColor Red
    return
}

Write-Host "  Package manager: $($pm.Cmd)`n" -ForegroundColor DarkGray

if ($pm.Refresh) {
    Write-Host '[>>] Refreshing package index...' -ForegroundColor Yellow
    & $pm.Cmd @($pm.Refresh) 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!!] Refresh failed (exit code $LASTEXITCODE). Check your network connection.`n" -ForegroundColor Red
        return
    }
}

Write-Host "[>>] Checking for available updates...`n" -ForegroundColor Yellow
# dnf check-update exits 100 when updates exist and 0 when there are none;
# pacman -Qu exits 1 on an empty list. Judge by output, not exit code.
# Discard stderr: every manager writes banners and progress there, and merged
# ErrorRecords stringify to their type name rather than their text.
$lines = @(& $pm.Cmd @($pm.List) 2>$null |
    ForEach-Object { "$_".Trim() } |
    Where-Object { $_ -and $_ -notmatch '^(Listing|Last metadata)' })

if (-not $lines) {
    Write-Host "[OK] Everything is already up to date.`n" -ForegroundColor Green
    return
}

# A full-distro upgrade can list hundreds of packages; show enough to judge by.
$preview = 15
$lines | Select-Object -First $preview | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
if ($lines.Count -gt $preview) {
    Write-Host "  ... and $($lines.Count - $preview) more" -ForegroundColor DarkGray
}
Write-Host "`n  $($lines.Count) update(s) available.`n" -ForegroundColor Cyan

$confirm = (Read-Host '  Proceed with updating all packages? (y/n)').Trim().ToLower()
if ($confirm -ne 'y') {
    Write-Host "`n  Update cancelled.`n" -ForegroundColor DarkGray
    return
}

Write-Host "`n[>>] Updating all packages...`n" -ForegroundColor Yellow
& $pm.Cmd @($pm.Update)

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[OK] Update complete.`n" -ForegroundColor Green
    # Kernel and glibc updates only take effect after a restart.
    if (Get-Command needs-restarting -ErrorAction SilentlyContinue) {
        & needs-restarting -r 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Host "  [!] A reboot is required to finish this update.`n" -ForegroundColor Yellow }
    } elseif (Test-Path '/var/run/reboot-required') {
        Write-Host "  [!] A reboot is required to finish this update.`n" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n[!!] Update exited with code $LASTEXITCODE.`n" -ForegroundColor Red
}
