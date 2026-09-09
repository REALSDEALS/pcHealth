#Requires -Version 7.0
# ============================================================================
# pcHealth -- Boot Repair (UEFI)
# Repairs the EFI boot files via CHKDSK, SFC and BCDBOOT.
# Best run from a recovery environment (WinRE/CMD) with Administrator rights.
#
# UEFI only. Windows 11 requires UEFI + GPT and pcHealth's minimum is build
# 26200, so every supported system boots UEFI. The old bootrec /fixmbr and
# /fixboot steps wrote MBR-era boot code that nothing on a GPT disk reads --
# /fixboot in fact returns "Access is denied" on EFI systems, which is why the
# real repair was always the bcdboot fallback underneath it.
# ============================================================================

if (Get-Command Set-PcTheme -ErrorAction SilentlyContinue) {
    Set-PcTheme 'Danger'
    Clear-PcHost
}

Write-Host "`n$('=' * 60)" -ForegroundColor Red
Write-Host "  Boot Repair  (UEFI)" -ForegroundColor Red
Write-Host "$('=' * 60)`n" -ForegroundColor Red
Write-Host "  WARNING: This operation modifies boot-critical files." -ForegroundColor Yellow
Write-Host "  Incorrect use can render the system unbootable." -ForegroundColor Yellow
Write-Host "  Only proceed if you understand what you are doing.`n" -ForegroundColor Yellow

# PEFirmwareType: 1 = legacy BIOS, 2 = UEFI. Refuse rather than guess -- the
# repair below writes EFI boot files, which do nothing on a BIOS/MBR install.
$firmwareType = try {
    (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name PEFirmwareType -ErrorAction Stop).PEFirmwareType
} catch {
    Write-Debug "PEFirmwareType registry property not found: $_"
    $null
}
if ($firmwareType -ne 2) {
    Write-Host "[!!] This system does not report UEFI firmware (PEFirmwareType = $firmwareType)." -ForegroundColor Red
    Write-Host "     pcHealth only repairs UEFI boot files. A legacy BIOS/MBR install" -ForegroundColor Yellow
    Write-Host "     needs recovery media and manual repair." -ForegroundColor Yellow
    Write-Host ''
    return
}

$confirm1 = (Read-Host "  Type 'yes' to continue or anything else to cancel").Trim().ToLower()
if ($confirm1 -ne 'yes') {
    Write-Host "`n  Cancelled.`n" -ForegroundColor DarkGray
    return
}

$confirm2 = (Read-Host "  Last chance -- type 'CONFIRM' in capitals to proceed").Trim()
if ($confirm2 -ne 'CONFIRM') {
    Write-Host "`n  Cancelled.`n" -ForegroundColor DarkGray
    return
}

function Get-WindowsDrive {
    # 'return' inside ForEach-Object is a continue, not a function exit.
    # Select-Object -First 1 ensures only the first match is used.
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -ne 'X' } | ForEach-Object {
        if (Test-Path (Join-Path $_.Root 'Windows\System32')) { "$($_.Name):" }
    } | Select-Object -First 1
}

Write-Host "`n[>>] Step 1/3 -- Disk repair..." -ForegroundColor Yellow
$win    = Get-WindowsDrive
$windir = if ($win) { Join-Path $win 'Windows' } else { $null }

if ($win) {
    $driveLetter = $win.TrimEnd(':')
    if (Test-Path 'X:\') {
        Repair-Volume -DriveLetter $driveLetter -OfflineScanAndFix
    } else {
        Write-Warning "Live session detected -- using online scan only. Run from WinRE for a full offline repair."
        Repair-Volume -DriveLetter $driveLetter -Scan
    }
} else { Write-Warning "Windows partition not found, skipping disk repair." }
Write-Host "[OK] Disk repair done.`n" -ForegroundColor Green

Write-Host "[>>] Step 2/3 -- SFC..." -ForegroundColor Yellow
if ($win) {
    if (Test-Path 'X:\') {
        # WinRE always maps its RAM-disk to X:\ — this is enforced by the Windows
        # boot environment and is not a user-configurable drive letter, so this
        # check reliably distinguishes a WinRE session from a normal Windows boot.
        # In WinRE, pass offline boot/win dirs so SFC targets the installed OS.
        Start-Process -FilePath "$env:SystemRoot\System32\sfc.exe" `
            -ArgumentList "/scannow /offbootdir=`"$win\`" /offwindir=`"$windir`"" `
            -Wait -NoNewWindow
    } else {
        # Live session: /offbootdir and /offwindir are not valid here; run the normal online scan.
        Write-Warning "Running live SFC scan — for a full offline repair, use WinRE."
        Start-Process -FilePath "$env:SystemRoot\System32\sfc.exe" `
            -ArgumentList '/scannow' `
            -Wait -NoNewWindow
    }
} else { Write-Warning "Skipping SFC — Windows partition not found." }
Write-Host "[OK] SFC done.`n" -ForegroundColor Green

Write-Host "[>>] Step 3/3 -- Rewriting EFI boot files (bcdboot)..." -ForegroundColor Yellow
if (-not $windir) {
    Write-Warning "Windows partition not found -- cannot rebuild the boot files."
} else {
    # The EFI System Partition normally has no drive letter; mountvol /S assigns
    # one so bcdboot can write to it. Pick a letter that is genuinely free --
    # hardcoding S: and testing Test-Path afterwards would silently target
    # whatever was already mounted there and then dismount the user's drive.
    $espLetter = 68..90 | ForEach-Object { [char]$_ } |
        Where-Object { -not (Test-Path "${_}:\") } | Select-Object -First 1

    if (-not $espLetter) {
        Write-Warning "No free drive letter available to mount the EFI System Partition."
    } else {
        & mountvol.exe "${espLetter}:" /S
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not mount the EFI System Partition (mountvol exit $LASTEXITCODE)."
        } else {
            try {
                # /f UEFI, not /f ALL: ALL also writes BIOS boot files, which
                # nothing in the supported range boots from.
                & bcdboot.exe $windir /s "${espLetter}:" /f UEFI
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] EFI boot files rewritten.`n" -ForegroundColor Green
                } else {
                    Write-Warning "bcdboot exited with code $LASTEXITCODE."
                }
            } finally {
                # Always release the ESP, even if bcdboot threw.
                & mountvol.exe "${espLetter}:" /D
            }
        }
    }
}

Write-Host "All steps completed. Reboot the system to verify.`n" -ForegroundColor Green
