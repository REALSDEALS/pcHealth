#Requires -Version 7.0
# ============================================================================
# pcHealth -- Scan + Repair (Linux)
# Counterpart to SFC + DISM. SFC compares system files against the component
# store; the package database is the same idea, so verify against that and
# reinstall whatever no longer matches.
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host '  Scan + Repair  (package integrity)' -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

$pm = Get-PcPackageManager
if (-not $pm) {
    Write-Host "[!!] No supported package manager found (apt/dnf/pacman/zypper).`n" -ForegroundColor Red
    return
}

$verifyCmd = $pm.Verify[0]
if (-not (Get-Command $verifyCmd -ErrorAction SilentlyContinue)) {
    Write-Host "[!!] $verifyCmd is not installed -- it does the checking, not $($pm.Cmd) itself." -ForegroundColor Red
    Write-Host "     Install it with: $($pm.Cmd) $($pm.Install -join ' ') $verifyCmd`n" -ForegroundColor DarkGray
    return
}

# -- Filesystem errors ---------------------------------------------------------
# Read-only: fsck cannot safely touch a mounted root, so report what the kernel
# has already seen and let the user schedule a repair from a live image.
Write-Host '[>>] Step 1/2 -- Checking the kernel log for filesystem errors...' -ForegroundColor Yellow
$fsErrors = @(& dmesg --level=err,warn 2>$null |
    Where-Object { $_ -match 'EXT4-fs error|XFS.*Corruption|BTRFS error|I/O error|filesystem.*read-only' })

if ($fsErrors) {
    Write-Host "[!!] The kernel has logged filesystem errors:`n" -ForegroundColor Red
    $fsErrors | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Write-Host "`n     Run fsck from a live image -- it cannot repair a mounted root.`n" -ForegroundColor Yellow
} else {
    Write-Host "[OK] No filesystem errors in the kernel log.`n" -ForegroundColor Green
}

# -- Package integrity ---------------------------------------------------------
Write-Host "[>>] Step 2/2 -- Verifying installed packages with $verifyCmd..." -ForegroundColor Yellow
Write-Host '     This reads every packaged file and takes several minutes.' -ForegroundColor DarkGray

$confirm = (Read-Host "`n  Start the verification? (y/n)").Trim().ToLower()
if ($confirm -ne 'y') {
    Write-Host "`n  Skipped.`n" -ForegroundColor DarkGray
    return
}

Write-Host ''
$verifyArgs = @($pm.Verify[1..($pm.Verify.Count - 1)])
# Merge stderr: debsums reports every changed file there, so discarding it would
# turn a corrupted system into a clean bill of health. Empty stderr lines
# stringify to the ErrorRecord type name, so drop those.
$findings = @(& $verifyCmd @verifyArgs 2>&1 |
    ForEach-Object { "$_".Trim() } |
    Where-Object { $_ -and $_ -ne 'System.Management.Automation.RemoteException' })

if (-not $findings) {
    Write-Host "[OK] Every packaged file matches the package database.`n" -ForegroundColor Green
    return
}

Write-Host "[!!] $($findings.Count) file(s) no longer match their package:`n" -ForegroundColor Red
$findings | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
if ($findings.Count -gt 20) {
    Write-Host "  ... and $($findings.Count - 20) more" -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '  Config files you edited yourself show up here too -- that is expected.' -ForegroundColor DarkGray
Write-Host "  Repair a package with: $($pm.Cmd) $($pm.Install -join ' ') --reinstall <package>`n" -ForegroundColor DarkGray
