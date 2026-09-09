#Requires -Version 7.0
# ============================================================================
# pcHealth -- Firmware Update (Linux)
# Counterpart to HP Image Assistant on Windows, but vendor-neutral: fwupd
# ships BIOS, dock, SSD and peripheral firmware from LVFS for most vendors.
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host '  Firmware Update  (fwupd / LVFS)' -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

if (-not (Get-Command fwupdmgr -ErrorAction SilentlyContinue)) {
    Write-Host '[!!] fwupdmgr is not installed.' -ForegroundColor Red
    Write-Host ''
    Write-Host '  Install it with your package manager:' -ForegroundColor DarkGray
    Write-Host '    Debian / Ubuntu:  apt install fwupd'    -ForegroundColor DarkGray
    Write-Host '    Fedora / RHEL:    dnf install fwupd'    -ForegroundColor DarkGray
    Write-Host '    Arch / CachyOS:   pacman -S fwupd'      -ForegroundColor DarkGray
    Write-Host '    openSUSE:         zypper install fwupd' -ForegroundColor DarkGray
    Write-Host ''
    return
}

Write-Host '[>>] Refreshing firmware metadata from LVFS...' -ForegroundColor Yellow
# --force refreshes even when the cached metadata is still considered fresh.
$refresh = & fwupdmgr refresh --force 2>&1 | ForEach-Object { "$_" }
$refresh | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
# Without fresh metadata the verdict below reflects whatever was cached, which
# may be months old -- say so rather than reporting a confident "up to date".
$staleMetadata = [bool]($refresh -match 'Failed to download|transient failure|Failed to connect')

Write-Host "`n[>>] Checking for firmware updates...`n" -ForegroundColor Yellow
$updates = & fwupdmgr get-updates 2>&1 | ForEach-Object { "$_" }

# fwupd is a daemon; the CLI still exits having printed nothing useful when it
# is masked or not running. Never fall through to the install prompt on that --
# an empty update list must not become an invitation to flash firmware.
if ($updates -match 'Failed to connect to daemon|Failed to load daemon|could not be activated') {
    Write-Host '[!!] Could not reach the fwupd daemon.' -ForegroundColor Red
    Write-Host '     Start it with: systemctl start fwupd' -ForegroundColor DarkGray
    Write-Host ''
    return
}

# fwupdmgr exits non-zero when there is simply nothing to do, so read the text.
if (-not $updates -or
    $updates -match 'No updatable devices|No updates available|Devices with no available firmware updates') {
    if ($staleMetadata) {
        Write-Host '[!] No updates found, but the LVFS metadata could not be refreshed.' -ForegroundColor Yellow
        Write-Host "    This answer is based on cached data -- check again once you are online.`n" -ForegroundColor DarkGray
    } else {
        Write-Host "[OK] All firmware is up to date.`n" -ForegroundColor Green
    }
    return
}

$updates | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

Write-Host ''
Write-Host '  [!] Firmware updates carry real risk. Do not power the machine off' -ForegroundColor Yellow
Write-Host '      while one is running, and plug in the charger on a laptop.'      -ForegroundColor Yellow
Write-Host ''

$confirm = (Read-Host '  Install these firmware updates? (y/n)').Trim().ToLower()
if ($confirm -ne 'y') {
    Write-Host "`n  Cancelled.`n" -ForegroundColor DarkGray
    return
}

Write-Host "`n[>>] Installing firmware updates...`n" -ForegroundColor Yellow
& fwupdmgr update

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[OK] Firmware update complete." -ForegroundColor Green
    Write-Host "     Some devices only apply the update on the next reboot.`n" -ForegroundColor DarkGray
} else {
    Write-Host "`n[!!] fwupdmgr exited with code $LASTEXITCODE.`n" -ForegroundColor Red
}
