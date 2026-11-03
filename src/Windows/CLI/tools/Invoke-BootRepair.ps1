#Requires -Version 7.0
# ============================================================================
# pcHealth -- Boot Repair (UEFI)
# Repairs the EFI boot files via CHKDSK, SFC and BCDBOOT.
# Needs PowerShell 7, so in practice it runs on a booted Windows install, not
# in WinRE (which has no pwsh).
#
# UEFI only. Windows 10 22H2 still runs on plenty of BIOS/MBR machines, so the
# firmware type is checked below and a legacy install is refused rather than
# half-repaired. The old bootrec /fixmbr and /fixboot steps wrote MBR-era boot
# code that nothing on a GPT disk reads -- /fixboot in fact returns "Access is
# denied" on EFI systems, which is why the real repair was always the bcdboot
# fallback underneath it.
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

# Rewriting the boot files changes what the TPM measures at boot, so a
# BitLocker-protected laptop asks for its recovery key on the next start --
# a key the owner often does not have. Suspending protection for one reboot
# avoids that; Windows resumes it automatically after the restart.
# Returns $true when it is safe to touch the boot files.
function Suspend-PcBitLocker {
    param([Parameter(Mandatory)][string]$Drive)
    try {
        $volume = Get-CimInstance -Namespace 'root/cimv2/Security/MicrosoftVolumeEncryption' `
            -ClassName Win32_EncryptableVolume -Filter "DriveLetter='$Drive'" -ErrorAction Stop
    } catch [Microsoft.Management.Infrastructure.CimException] {
        # No BitLocker namespace means this edition has no BitLocker at all.
        if ($_.Exception.NativeErrorCode -eq 'InvalidNamespace') { return $true }
        Write-Warning "Could not read the BitLocker state of $Drive -- $($_.Exception.Message)"
        return $false
    }
    # ProtectionStatus: 0 = off, 1 = on, 2 = unknown (volume locked).
    if (-not $volume -or $volume.ProtectionStatus -eq 0) { return $true }

    $result = Invoke-CimMethod -InputObject $volume -MethodName DisableKeyProtectors `
        -Arguments @{ DisableCount = [uint32]1 } -ErrorAction SilentlyContinue
    if ($result -and $result.ReturnValue -eq 0) {
        Write-Host "[OK] BitLocker on $Drive suspended until the next restart." -ForegroundColor Green
        return $true
    }
    Write-Warning "Could not suspend BitLocker on $Drive (return value $($result.ReturnValue))."
    return $false
}

# Windows PE (and so WinRE) sets this key. Testing for an X: drive instead
# would mistake a USB stick or mapped drive on X: for a recovery session.
$inWinPE = Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT'

Write-Host "`n[>>] Step 1/3 -- Disk repair..." -ForegroundColor Yellow
$win    = Get-WindowsDrive
$windir = if ($win) { Join-Path $win 'Windows' } else { $null }

if ($win) {
    $driveLetter = $win.TrimEnd(':')
    if ($inWinPE) {
        Repair-Volume -DriveLetter $driveLetter -OfflineScanAndFix
    } else {
        Write-Warning "Live session detected -- using online scan only. Run from WinRE for a full offline repair."
        Repair-Volume -DriveLetter $driveLetter -Scan
    }
} else { Write-Warning "Windows partition not found, skipping disk repair." }
Write-Host "[OK] Disk repair done.`n" -ForegroundColor Green

Write-Host "[>>] Step 2/3 -- SFC..." -ForegroundColor Yellow
if ($win) {
    if ($inWinPE) {
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
} elseif (-not (Suspend-PcBitLocker -Drive $win)) {
    Write-Warning "Boot files left untouched: rewriting them with BitLocker active can"
    Write-Warning "lock the system behind its recovery key. Suspend BitLocker manually"
    Write-Warning "(manage-bde -protectors -disable $win -RebootCount 1) and run this again."
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
