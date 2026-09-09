#Requires -Version 7.0
# ============================================================================
# pcHealth -- System Information
# ============================================================================

if ($IsLinux) {
    $hostname  = [System.Net.Dns]::GetHostName()
    $kernel    = (Get-PcCommandOutput 'uname'  @('-r')) ?? 'N/A'
    $arch      = (Get-PcCommandOutput 'uname'  @('-m')) ?? 'N/A'
    $uptime    = (Get-PcCommandOutput 'uptime' @('-p')) ?? 'N/A'
    $user      = (Get-PcDesktopUser)?.Name     ?? 'N/A'

    $osName = (Get-LinuxDistroInfo)['PRETTY_NAME']

    # RAM
    $memInfo = @{}
    if (Test-Path '/proc/meminfo') {
        Get-Content '/proc/meminfo' | ForEach-Object {
            if ($_ -match '^(\w+):\s+(\d+)') {
                $memInfo[$Matches[1]] = [long]$Matches[2]
            }
        }
    }
    $totalRamGB = if ($memInfo['MemTotal'])     { [Math]::Round($memInfo['MemTotal']     / 1MB, 2) } else { 'N/A' }
    $usedRamGB  = if ($memInfo['MemTotal'] -and $memInfo['MemAvailable']) {
                      [Math]::Round(($memInfo['MemTotal'] - $memInfo['MemAvailable']) / 1MB, 2)
                  } else { 'N/A' }

    # CPU model (brief — Hardware Info has the full lscpu dump)
    $cpu = 'N/A'
    if (Test-Path '/proc/cpuinfo') {
        $cpuLine = Get-Content '/proc/cpuinfo' | Where-Object { $_ -match '^model name' } | Select-Object -First 1
        if ($cpuLine -match '^model name\s*:\s*(.+)') { $cpu = $Matches[1].Trim() }
    }

    # Machine model from DMI
    $vendor = try { (Get-Content '/sys/class/dmi/id/sys_vendor'   -ErrorAction Stop).Trim() } catch { $null }
    $model  = try { (Get-Content '/sys/class/dmi/id/product_name' -ErrorAction Stop).Trim() } catch { $null }
    $machine = if ($vendor -and $model) { "$vendor $model" } elseif ($model) { $model } else { 'N/A' }

    # Firmware type
    $firmwareType = if (Test-Path '/sys/firmware/efi') { 'UEFI' } else { 'Legacy BIOS' }

    # Secure Boot
    $secureBoot = 'N/A'
    $mokOut = Get-PcCommandOutput 'mokutil' @('--sb-state')
    if ($mokOut) {
        $secureBoot = if ($mokOut -match 'enabled') { 'Enabled' } elseif ($mokOut -match 'disabled') { 'Disabled' } else { $mokOut }
    } elseif (Test-Path '/sys/firmware/efi/efivars') {
        $sbVar = Get-ChildItem '/sys/firmware/efi/efivars' -Filter 'SecureBoot-*' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($sbVar) {
            try {
                $bytes = [System.IO.File]::ReadAllBytes($sbVar.FullName)
                $secureBoot = if ($bytes.Length -ge 5 -and $bytes[4] -eq 1) { 'Enabled' } else { 'Disabled' }
            } catch {
                # If reading the efivar fails, mark secure boot state as unknown
                $secureBoot = 'Unknown'
            }
        }
    }

    # Last boot timestamp
    $lastBoot = (Get-PcCommandOutput 'uptime' @('-s')) ?? 'N/A'

    # Desktop environment / Wayland or X11
    $de      = $env:XDG_CURRENT_DESKTOP ?? $env:DESKTOP_SESSION ?? 'Unknown'
    $session = $env:WAYLAND_DISPLAY ? 'Wayland' : ($env:DISPLAY ? 'X11' : 'Unknown')

    # Shell (basename only)
    $shell = $env:SHELL ?? 'Unknown'
    if ($shell -match '/([^/]+)$') { $shell = $Matches[1] }

    # Installed package count (distro-aware)
    $pkgCount = 'N/A'
    if (Get-Command pacman -ErrorAction SilentlyContinue) {
        $pkgCount = "$(( & pacman -Q 2>$null).Count) (pacman)"
    } elseif (Get-Command dpkg -ErrorAction SilentlyContinue) {
        $pkgCount = "$(( & dpkg -l 2>$null | Where-Object { $_ -match '^ii' }).Count) (dpkg)"
    } elseif (Get-Command rpm -ErrorAction SilentlyContinue) {
        $pkgCount = "$(( & rpm -qa 2>$null).Count) (rpm)"
    }

    # Timezone
    # timedatectl is unavailable without systemd (containers, WSL, OpenRC distros).
    $timezone = Get-PcCommandOutput 'timedatectl' @('show', '--property=Timezone', '--value')
    if (-not $timezone) { $timezone = $env:TZ ?? (Get-PcCommandOutput 'date' @('+%Z')) ?? 'N/A' }

    [PSCustomObject]@{
        'Computer Name'  = $hostname
        'Machine'        = $machine
        'OS Name'        = $osName
        'Kernel'         = $kernel
        'Architecture'   = $arch
        'CPU'            = $cpu
        'RAM Used (GB)'  = $usedRamGB
        'RAM Total (GB)' = $totalRamGB
        'Firmware'       = $firmwareType
        'Secure Boot'    = "$secureBoot  [*]"
        'Uptime'         = $uptime
        'Last Boot'      = $lastBoot
        'Desktop'        = $de
        'Session'        = $session
        'Shell'          = $shell
        'Packages'       = $pkgCount
        'Timezone'       = $timezone
        'User'           = $user
    } | Format-List | Out-Host
    Write-Host '  [*] Secure Boot shows the UEFI firmware state only. On Linux, actual enforcement depends on shim/MOK setup and varies per distro.' -ForegroundColor DarkGray

} else {
    $os    = Get-CimInstance -ClassName Win32_OperatingSystem
    $cs    = Get-CimInstance -ClassName Win32_ComputerSystem
    $cpu   = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $ntCv  = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue

    $winVer    = $ntCv.DisplayVersion
    $ubr       = $ntCv.UBR
    $fullBuild = if ($ubr) { "$($os.BuildNumber).$ubr" } else { $os.BuildNumber }

    $fw        = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
    # $env:firmware_type is only set in WinPE/MDT; in a normal session it is always empty.
    # Read PEFirmwareType from the registry instead: 1 = BIOS, 2 = UEFI.
    # Use -Name so only this one value is retrieved; accessing a missing property on the
    # whole key would return $null in PowerShell, but -Name throws a clean error instead.
    $fwTypeRaw = try {
        (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' `
            -Name PEFirmwareType -ErrorAction Stop).PEFirmwareType
    } catch {
        # PEFirmwareType is absent on some OEM or pre-UEFI systems; log and fall through.
        Write-Debug "PEFirmwareType registry property not found: $_"
        $null
    }
    $fwType    = switch ($fwTypeRaw) { 2 { 'UEFI' } 1 { 'Legacy BIOS' } default { 'Unknown' } }
    $fwVersion = if ($fw.SMBIOSBIOSVersion) { $fw.SMBIOSBIOSVersion } else { 'Unknown' }
    $fwDate    = if ($fw.ReleaseDate) { $fw.ReleaseDate.ToString('yyyy-MM-dd') } else { 'Unknown' }

    $secureBoot = try {
        if (Confirm-SecureBootUEFI) { 'Enabled' } else { 'Disabled' }
    } catch { 'N/A' }

    $tpmState   = Get-Tpm -ErrorAction SilentlyContinue
    $tpmWmi     = Get-CimInstance -Namespace 'root\cimv2\security\microsofttpm' `
                      -ClassName Win32_Tpm -ErrorAction SilentlyContinue
    $tpmVersion = if ($tpmWmi.SpecVersion) { ($tpmWmi.SpecVersion -split ',')[0].Trim() } else { 'N/A' }
    $tpmStatus  = if ($tpmState.TpmReady)      { 'Ready' }
                  elseif ($tpmState.TpmPresent) { 'Present (not ready)' }
                  else { 'Not present' }

    [PSCustomObject]@{
        'Computer Name'    = $env:COMPUTERNAME
        'OS Name'          = $os.Caption
        'Windows Version'  = $winVer
        'OS Build'         = $fullBuild
        'Architecture'     = $os.OSArchitecture
        'Manufacturer'     = $cs.Manufacturer
        'Model'            = $cs.Model
        'Firmware Type'    = $fwType
        'Firmware Version' = $fwVersion
        'Firmware Date'    = $fwDate
        'Secure Boot'      = $secureBoot
        'TPM Version'      = $tpmVersion
        'TPM Status'       = $tpmStatus
        'Processor'        = $cpu.Name
        'Total RAM (GB)'   = [Math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        'Install Date'     = $os.InstallDate.ToString('yyyy-MM-dd')
        'Last Boot'        = $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss')
        'System Directory' = $os.SystemDirectory
        'Windows Directory'= $os.WindowsDirectory
    } | Format-List | Out-Host
}
