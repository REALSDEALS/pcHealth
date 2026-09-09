#Requires -Version 7.0
# ============================================================================
# pcHealth -- Disk Optimization (Linux)
# Counterpart to dfrgui.exe on Windows. Linux filesystems do not need
# defragmenting, so the useful half of that job is discarding unused blocks
# on SSDs, which is what fstrim does.
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host '  Disk Optimization' -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

# rotational = 1 means spinning rust: nothing to trim, and ext4/btrfs/xfs do not
# fragment the way NTFS does, so there is nothing to defragment either.
$disks = @(Get-ChildItem '/sys/block' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '^(loop|ram|zram|sr)' } |
    ForEach-Object {
        $rotational = try { (Get-Content (Join-Path $_.FullName 'queue/rotational') -Raw -ErrorAction Stop).Trim() } catch { $null }
        [PSCustomObject]@{
            Disk = $_.Name
            Type = switch ($rotational) { '0' { 'SSD / NVMe' } '1' { 'HDD' } default { 'Unknown' } }
        }
    })

if ($disks) {
    $disks | Format-Table -AutoSize | Out-Host
    if ($disks.Type -notcontains 'SSD / NVMe') {
        Write-Host "  No solid-state device detected -- there is nothing to trim." -ForegroundColor Yellow
        Write-Host "  Linux filesystems do not need defragmenting.`n" -ForegroundColor DarkGray
        return
    }
}

if (-not (Get-Command fstrim -ErrorAction SilentlyContinue)) {
    Write-Host "[!!] fstrim not found. Install util-linux.`n" -ForegroundColor Red
    return
}

# Many distros already run fstrim.timer weekly; say so rather than implying
# the manual run was necessary.
$timer = Get-PcCommandOutput 'systemctl' @('is-enabled', 'fstrim.timer')
if ($timer -eq 'enabled') {
    Write-Host "  Note: fstrim.timer is enabled, so this already runs weekly.`n" -ForegroundColor DarkGray
}

Write-Host "[>>] Trimming all mounted filesystems that support it..." -ForegroundColor Yellow
Write-Host "     This can take a minute on a large or nearly full disk.`n" -ForegroundColor DarkGray

# --all walks every mounted filesystem; --verbose reports bytes freed per mount.
& fstrim --all --verbose 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[OK] Trim complete.`n" -ForegroundColor Green
} else {
    Write-Host "`n[!!] fstrim exited with code $LASTEXITCODE.`n" -ForegroundColor Red
}
