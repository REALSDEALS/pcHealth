#Requires -Version 7.0
# ============================================================================
# pcHealth -- View System Logs (Linux)
# Shows recent error/warning entries from the systemd journal.
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host "  System Logs (journalctl)" -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

if (-not (Get-Command journalctl -ErrorAction SilentlyContinue)) {
    Write-Host "[!!] journalctl not found. This system may not use systemd.`n" -ForegroundColor Red
    return
}

Write-Host "  [1]  Errors from today"
Write-Host "  [2]  Last 100 error/warning entries"
Write-Host "  [3]  Boot messages (current boot)"
Write-Host "  [4]  Kernel messages (dmesg)"
Write-Host "  [5]  Failed services"
Write-Host "  [B]  Back`n"

$choice = (Read-Host "  Choice").Trim().ToUpper()

switch ($choice) {
    '1' {
        Write-Host "`n[>>] Errors from today...`n" -ForegroundColor Yellow
        & journalctl --priority=err --since=today --no-pager
    }
    '2' {
        Write-Host "`n[>>] Last 100 error/warning entries...`n" -ForegroundColor Yellow
        & journalctl --priority=warning -n 100 --no-pager
    }
    '3' {
        Write-Host "`n[>>] Boot messages (current boot)...`n" -ForegroundColor Yellow
        & journalctl -b --no-pager | tail -n 100
    }
    '4' {
        Write-Host "`n[>>] Kernel messages...`n" -ForegroundColor Yellow
        & dmesg --level=err,warn 2>$null | tail -n 50
    }
    '5' {
        Write-Host "`n[>>] Failed systemd units...`n" -ForegroundColor Yellow
        $failed = Get-PcCommandOutput 'systemctl' @('--failed', '--no-legend', '--no-pager')
        if ($failed) {
            Write-Host $failed
            Write-Host "`n  Inspect one with: journalctl -u <unit> -b" -ForegroundColor DarkGray
        } else {
            Write-Host '  No failed units.' -ForegroundColor Green
        }
    }
    'B' { return }
    default { Write-Host "`n  Invalid choice.`n" -ForegroundColor Red }
}

Write-Host ''
