#Requires -Version 7.0
# ============================================================================
# pcHealth -- Boot Repair (Linux, UEFI)
# Reinstalls the bootloader's EFI files. Supports systemd-boot, GRUB and Limine.
#
# UEFI only, deliberately. pcHealth's minimum is kernel 7.0, and repairing a
# legacy BIOS/MBR setup means writing raw boot code to the disk -- a different
# and far riskier operation than reinstalling an EFI binary onto the ESP.
#
# Every repair below runs the bootloader's own official command. pcHealth never
# writes boot sectors itself and never guesses which loader you use.
# ============================================================================

if (Get-Command Set-PcTheme -ErrorAction SilentlyContinue) {
    Set-PcTheme 'Danger'
    Clear-PcHost
}

Write-Host "`n$('=' * 60)" -ForegroundColor Red
Write-Host '  Boot Repair  (UEFI)' -ForegroundColor Red
Write-Host "$('=' * 60)`n" -ForegroundColor Red
Write-Host '  WARNING: This operation modifies boot-critical files.' -ForegroundColor Yellow
Write-Host '  Incorrect use can render the system unbootable.' -ForegroundColor Yellow
Write-Host "  Only proceed if you understand what you are doing.`n" -ForegroundColor Yellow

# -- Image-based guard ---------------------------------------------------------
# On ostree systems the bootloader entries are generated from the deployments
# (/boot/loader/entries). Reinstalling GRUB or systemd-boot by hand here fights
# whatever produced those entries; `bootc`/`rpm-ostree` own this, not pcHealth.
if (Test-PcImageBasedSystem) {
    Write-Host '[!!] This is an image-based system (ostree).' -ForegroundColor Red
    Write-Host '     Its bootloader is managed by the deployment, not by hand.' -ForegroundColor Yellow
    Write-Host '     Roll back to a working deployment instead:' -ForegroundColor Yellow
    Write-Host '       rpm-ostree status      # list deployments' -ForegroundColor DarkGray
    Write-Host '       rpm-ostree rollback    # boot the previous one' -ForegroundColor DarkGray
    Write-Host ''
    return
}

# -- Firmware guard ------------------------------------------------------------
if (-not (Test-Path '/sys/firmware/efi')) {
    Write-Host '[!!] This system booted in legacy BIOS mode (no /sys/firmware/efi).' -ForegroundColor Red
    Write-Host '     pcHealth only repairs UEFI bootloaders.' -ForegroundColor Yellow
    Write-Host ''
    return
}

# EFI binary name and GRUB target follow the firmware's bitness, not the CPU's:
# a 64-bit CPU can ship 32-bit UEFI firmware, and BOOTX64 will not boot there.
$machine  = (Get-PcCommandOutput 'uname' @('-m')) ?? 'x86_64'
$fwBits   = try { (Get-Content '/sys/firmware/efi/fw_platform_size' -Raw -ErrorAction Stop).Trim() } catch { '64' }
$efiName, $grubTarget = switch -Regex ($machine) {
    '^aarch64|^arm64' { 'BOOTAA64.EFI', 'arm64-efi'; break }
    default           { if ($fwBits -eq '32') { 'BOOTIA32.EFI', 'i386-efi' } else { 'BOOTX64.EFI', 'x86_64-efi' } }
}

# -- Locate the EFI System Partition -------------------------------------------
# Only trust a mounted vfat partition. Mounting one ourselves would mean picking
# a candidate by guesswork, on the one filesystem where a wrong guess is fatal.
$esp = $null
foreach ($candidate in @('/efi', '/boot/efi', '/boot')) {
    $fsType = Get-PcCommandOutput 'findmnt' @('-rno', 'FSTYPE', '--target', $candidate)
    if ($fsType -eq 'vfat') { $esp = $candidate; break }
}

if (-not $esp) {
    Write-Host '[!!] No mounted EFI System Partition found at /efi, /boot/efi or /boot.' -ForegroundColor Red
    Write-Host '     Mount it first, then run this tool again. Candidates:' -ForegroundColor Yellow
    & lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,MOUNTPOINT 2>$null |
        Where-Object { $_ -match 'EFI System|vfat|NAME' } |
        ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Write-Host ''
    return
}

Write-Host "  Firmware:     UEFI ($fwBits-bit, $machine)" -ForegroundColor DarkGray
Write-Host "  ESP:          $esp" -ForegroundColor DarkGray
Write-Host "  EFI binary:   $efiName`n" -ForegroundColor DarkGray

# -- Detect which bootloaders are installed ------------------------------------
$loaders = @()

if ((Test-Path (Join-Path $esp 'EFI/systemd')) -or (Get-Command bootctl -ErrorAction SilentlyContinue)) {
    $installed = Test-Path (Join-Path $esp 'EFI/systemd')
    $loaders += [PSCustomObject]@{
        Name     = 'systemd-boot'
        Present  = $installed
        Commands = [string[][]]@(, @('bootctl', 'install', "--esp-path=$esp"))
    }
}

$grubCmd = @('grub-install', 'grub2-install') |
    Where-Object { Get-Command $_ -CommandType Application -ErrorAction SilentlyContinue } |
    Select-Object -First 1
if ($grubCmd) {
    # Fedora/RHEL name everything grub2-* and keep the config under /boot/grub2.
    $mkconfig = if ($grubCmd -eq 'grub2-install') { 'grub2-mkconfig' } else { 'grub-mkconfig' }
    $grubDir  = if ($grubCmd -eq 'grub2-install') { '/boot/grub2' } else { '/boot/grub' }
    $distroId = (Get-LinuxDistroInfo)['ID']
    $bootId   = if ($distroId) { $distroId } else { 'linux' }
    $loaders += [PSCustomObject]@{
        Name     = 'GRUB'
        Present  = (Test-Path $grubDir) -or (Test-Path (Join-Path $esp 'EFI/grub'))
        # Commas matter: newline-separated elements collapse into one flat list,
        # which would make $cmd[0] a single character instead of the command.
        Commands = [string[][]]@(
            @($grubCmd, "--target=$grubTarget", "--efi-directory=$esp", "--bootloader-id=$bootId"),
            @($mkconfig, '-o', (Join-Path $grubDir 'grub.cfg'))
        )
    }
}

# Limine has no upstream UEFI installer -- the documented procedure is to copy
# the EFI binary onto the ESP. Distros ship their own helper, so prefer that.
$limineHelper = @('limine-update', 'limine-install') |
    Where-Object { Get-Command $_ -CommandType Application -ErrorAction SilentlyContinue } |
    Select-Object -First 1
$limineSource = Join-Path '/usr/share/limine' $efiName
if ($limineHelper -or (Test-Path $limineSource)) {
    $limineCommands = if ($limineHelper) {
        [string[][]]@(, @($limineHelper))
    } else {
        # Never `limine bios-install` here: that writes an MBR stage and is
        # documented as BIOS-only.
        [string[][]]@(
            @('mkdir', '-p', (Join-Path $esp 'EFI/BOOT')),
            @('cp', $limineSource, (Join-Path $esp "EFI/BOOT/$efiName"))
        )
    }
    $loaders += [PSCustomObject]@{
        Name     = 'Limine'
        Present  = (Test-Path (Join-Path $esp "EFI/BOOT/$efiName")) -or
                   (@('limine.conf', 'limine/limine.conf', 'boot/limine/limine.conf') |
                        Where-Object { Test-Path (Join-Path $esp $_) }).Count -gt 0
        Commands = $limineCommands
    }
}

if (-not $loaders) {
    Write-Host '[!!] No supported bootloader found (systemd-boot, GRUB or Limine).' -ForegroundColor Red
    Write-Host '     Install your bootloader''s package first, then run this tool again.' -ForegroundColor Yellow
    Write-Host ''
    return
}

# -- Choose -------------------------------------------------------------------
Write-Host '  Detected bootloaders:' -ForegroundColor Cyan
for ($i = 0; $i -lt $loaders.Count; $i++) {
    $state = if ($loaders[$i].Present) { 'installed on this ESP' } else { 'tooling present, not installed here' }
    Write-PcOption "$($i + 1)" $loaders[$i].Name "($state)"
}
Write-PcOption 'B' 'Cancel'
Write-Host ''

$choice = (Read-Host '  Which bootloader should be repaired?').Trim()
if ($choice -eq 'B' -or $choice -eq 'b') {
    Write-Host "`n  Cancelled.`n" -ForegroundColor DarkGray
    return
}
$index = 0
if (-not [int]::TryParse($choice, [ref]$index) -or $index -lt 1 -or $index -gt $loaders.Count) {
    Write-Host "`n  Invalid choice.`n" -ForegroundColor Red
    return
}
$loader = $loaders[$index - 1]

# -- Confirm, showing exactly what will run ------------------------------------
Write-Host "`n  These commands will run as root:`n" -ForegroundColor Yellow
foreach ($cmd in $loader.Commands) { Write-Host "    $($cmd -join ' ')" -ForegroundColor White }
Write-Host ''

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

# -- Repair --------------------------------------------------------------------
Write-Host ''
foreach ($cmd in $loader.Commands) {
    Write-Host "[>>] $($cmd -join ' ')" -ForegroundColor Yellow
    & $cmd[0] @($cmd[1..($cmd.Count - 1)]) 2>&1 |
        ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[!!] Failed with exit code $LASTEXITCODE -- stopping here." -ForegroundColor Red
        Write-Host '     The system may still boot from its existing entry. Do not reboot' -ForegroundColor Yellow
        Write-Host '     until you have resolved this, and keep a live USB to hand.' -ForegroundColor Yellow
        Write-Host ''
        return
    }
}

Write-Host "[OK] $($loader.Name) reinstalled on $esp.`n" -ForegroundColor Green

# efibootmgr lets the user confirm the firmware entry exists before rebooting --
# a copied EFI binary with no boot entry still leaves an unbootable machine.
if (Get-Command efibootmgr -ErrorAction SilentlyContinue) {
    Write-Host '  Current firmware boot entries:' -ForegroundColor Cyan
    & efibootmgr 2>$null | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Write-Host ''
}

Write-Host '  Verify the entry above before rebooting.' -ForegroundColor Yellow
Write-Host ''
