Write-Host "Boot Record Repair Script"
Write-Host "As part of the pcHealth script: check GitHub for more info; github.com/realsdeals/pcHealth"
Write-Host "-------------------------"
# -------------------------------
Write-Host "Starting Boot Record Repair..."

function Get-WindowsDrive {
    $candidates = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -ne 'X' }
    foreach ($d in $candidates) {
        if (Test-Path (Join-Path "$($d.Root)" "Windows\System32")) {
            return ($d.Name + ":")
        }
    }
    return $null
}

function Run_Chkdsk {
    Write-Host "`n[CHKDSK] Scanning disk with /f /r..." -ForegroundColor Cyan
    $win = Get-WindowsDrive
    if (-not $win) { Write-Warning "No Windows partition found."; return }
    cmd /c "chkdsk $win /f /r"
    Write-Host "[CHKDSK] Completed.`n"
}

function Run_SFC {
    Write-Host "[SFC] Running offline SFC /scannow..." -ForegroundColor Cyan
    $win = Get-WindowsDrive
    if (-not $win) { Write-Warning "No Windows partition found."; return }
    $windir = Join-Path $win "Windows"
    cmd /c "sfc /scannow /offbootdir=$win\ /offwindir=$windir"
    Write-Host "[SFC] Completed.`n"
}

function Try_EfiRebuild {
    $win = Get-WindowsDrive
    if (-not $win) { Write-Warning "No Windows partition found."; return }
    $windir = Join-Path $win "Windows"

    Write-Host "[EFI] Mounting EFI partition as S:..." -ForegroundColor Cyan
    cmd /c "mountvol S: /S" 2>$null

    if (-not (Test-Path "S:\")) {
        Write-Warning "Failed to mount EFI partition. Skipping BCDBOOT."
        return
    }

    Write-Host "[EFI] Running BCDBOOT from $windir..." -ForegroundColor Cyan
    cmd /c "bcdboot $windir /s S: /f ALL"
    Write-Host "[EFI] EFI boot files recreated."
}

function Run_Bootrec {
    Write-Host "[BOOTREC] Starting boot repair..." -ForegroundColor Cyan

    cmd /c "bootrec /fixmbr"
    $fixboot = cmd /c "bootrec /fixboot" 2>&1
    cmd /c "bootrec /scanos"
    cmd /c "bootrec /rebuildbcd"

    if ($fixboot -match 'Access is denied' -or $fixboot -match 'Toegang geweigerd') {
        Write-Warning "[BOOTREC] Access denied on /fixboot. Attempting BCDBOOT fallback..."
        Try-EfiRebuild
    }

    Write-Host "[BOOTREC] Boot repair finished.`n"
}

# Run back
Write-Host "Starting full boot repair routine..." -ForegroundColor Green
Run_Chkdsk
Run_SFC
Run_Bootrec
Write-Host "`nAll steps completed. You may now reboot the system." -ForegroundColor Green