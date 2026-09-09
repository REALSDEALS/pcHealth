#Requires -Version 7.0
# ============================================================================
# pcHealth -- Hardware Information
# CPU, GPU, Storage (SMART via smartmontools), RAM, Chipset.
# ============================================================================

function Write-SectionHeader {
    param([string]$Title)
    $prefix = '--- '
    $fill   = '-' * [Math]::Max(0, 90 - $prefix.Length - $Title.Length - 1)
    Write-Host "`n$prefix$Title $fill" -ForegroundColor Cyan
}

function Find-Smartctl {
    $inPath = Get-Command smartctl -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }
    if (-not $IsLinux) {
        $prog = "$env:ProgramFiles\smartmontools\bin\smartctl.exe"
        if (Test-Path $prog) { return $prog }
    }
    return $null
}

$smartctl = Find-Smartctl
if (-not $smartctl) {
    Write-Host "`n[pcHealth] smartmontools is recommended for full SMART disk health data (life %, temperature, power-on hours)." -ForegroundColor Yellow
    Write-Host '           Without it, life %, temperature and power-on hours are unavailable.' -ForegroundColor DarkGray

    $prompt = if ($IsLinux) { '  Install now? [Y/N]' } else { '  Install now via winget? [Y/N]' }
    $answer = (Read-Host $prompt).Trim()
    if ($answer -match '^[Yy]') {
        if ($IsLinux) {
            $pm = Get-PcPackageManager
            if ($Global:PcImageBased) {
                Write-Host '[!!] Image-based system -- install smartmontools with Homebrew or Distrobox.' -ForegroundColor Yellow
            } elseif ($pm) { & $pm.Cmd @($pm.Install) smartmontools }
            else { Write-Host '[!!] No supported package manager found. Install smartmontools manually.' -ForegroundColor Yellow }
        } else {
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                Write-Host '[!!] winget not available. Install from: https://www.smartmontools.org/' -ForegroundColor Yellow
            } else {
                winget install --source winget --id smartmontools.smartmontools -e --silent `
                    --accept-package-agreements --accept-source-agreements
                $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                            [System.Environment]::GetEnvironmentVariable('Path','User')
            }
        }
        $smartctl = Find-Smartctl
        if ($smartctl) {
            Write-Host "  [OK] smartmontools installed.`n" -ForegroundColor Green
        } else {
            Write-Host "  [!!] Install may need a restart to take effect.`n" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Skipping — SMART data will be limited.`n" -ForegroundColor DarkGray
    }
}

if ($IsLinux) {
    # -- CPU ------------------------------------------------------------------
    Write-SectionHeader 'CPU'
    if (Get-Command lscpu -ErrorAction SilentlyContinue) {
        $lscpuData = @{}
        & lscpu 2>$null | ForEach-Object {
            if ($_ -match '^(.+?):\s+(.+)$') { $lscpuData[$Matches[1].Trim()] = $Matches[2].Trim() }
        }
        $maxMHz = $lscpuData['CPU max MHz']
        $maxMHzStr = if ($maxMHz) { "$([Math]::Round([double]($maxMHz -replace ',', '.'), 0)) MHz" } else { 'N/A' }
        [PSCustomObject]@{
            'CPU Name'       = $lscpuData['Model name']         ?? 'N/A'
            'Architecture'   = $lscpuData['Architecture']       ?? 'N/A'
            'Cores'          = $lscpuData['Core(s) per socket'] ?? 'N/A'
            'Threads'        = $lscpuData['CPU(s)']             ?? 'N/A'
            'Max Speed'      = $maxMHzStr
            'L1d Cache'      = $lscpuData['L1d cache']          ?? 'N/A'
            'L1i Cache'      = $lscpuData['L1i cache']          ?? 'N/A'
            'L2 Cache'       = $lscpuData['L2 cache']           ?? 'N/A'
            'L3 Cache'       = $lscpuData['L3 cache']           ?? 'N/A'
            'Virtualization' = $lscpuData['Virtualization']     ?? 'N/A'
        } | Format-List | Out-Host
    } elseif (Test-Path '/proc/cpuinfo') {
        Get-Content '/proc/cpuinfo' | Where-Object { $_ -match '^(model name|cpu MHz|cpu cores|siblings)' } | Out-Host
    } else {
        Write-Warning "CPU information not available."
    }

    # -- GPU ------------------------------------------------------------------
    Write-SectionHeader 'GPU'
    if (Get-Command lspci -ErrorAction SilentlyContinue) {
        $gpuLines = & lspci 2>$null | Where-Object { $_ -match 'VGA|3D|Display' }
        if ($gpuLines) {
            $gpuObjects = @($gpuLines | ForEach-Object {
                if ($_ -match '^[\w:\.]+\s+(?:VGA compatible controller|Display controller|3D controller):\s*(.+)$') {
                    [PSCustomObject]@{ GPU = $Matches[1].Trim() }
                }
            })
            if ($gpuObjects) { $gpuObjects | Format-Table -AutoSize -HideTableHeaders | Out-Host } else { $gpuLines | Out-Host }
        } else { Write-Warning "No GPU found via lspci." }
    } else {
        Write-Warning "lspci not available. Install pciutils."
    }

    # -- Storage --------------------------------------------------------------
    Write-SectionHeader 'Storage'
    if ($smartctl) {
        $scanJson = (& $smartctl --scan --json 2>$null) -join "`n"
        $scanData = $scanJson | ConvertFrom-Json -ErrorAction SilentlyContinue
        $devices  = $scanData.devices
        if ($devices) {
            $rows = @(foreach ($dev in $devices) {
                $devArgs = @('-a', $dev.name, '--json')
                if ($dev.type -and $dev.type -ne 'auto') { $devArgs += @('-d', $dev.type) }
                $devJson = (& $smartctl @devArgs 2>$null) -join "`n"
                $data    = $devJson | ConvertFrom-Json -ErrorAction SilentlyContinue
                if (-not $data -or -not $data.model_name) { continue }
                $mediaType = if ($dev.type -eq 'nvme') { 'SSD' } elseif ($data.rotation_rate -gt 0) { 'HDD' } else { 'SSD' }
                $lifeLeft = 'N/A'
                if ($dev.type -eq 'nvme') {
                    $pct = $data.nvme_smart_health_information_log.percentage_used
                    if ($null -ne $pct) { $lifeLeft = "$([Math]::Max(0, 100 - [int]$pct))%" }
                } elseif ($mediaType -eq 'SSD') {
                    $attr = $data.ata_smart_attributes.table | Where-Object { $_.id -in @(231, 202, 177) } | Select-Object -First 1
                    if ($attr) { $lifeLeft = "$($attr.value)%" }
                }
                [PSCustomObject]@{
                    Model       = $data.model_name
                    Type        = $mediaType
                    'Size (GB)' = if ($data.capacity.bytes)          { [Math]::Round($data.capacity.bytes / 1GB, 0) } else { 'N/A' }
                    'Temp (C)'  = if ($null -ne $data.temperature.current) { $data.temperature.current }             else { 'N/A' }
                    Hours       = if ($data.power_on_time.hours)     { $data.power_on_time.hours }                   else { 'N/A' }
                    'Life Left' = $lifeLeft
                    Health      = if ($data.smart_status.passed -eq $true) { 'Healthy' } elseif ($data.smart_status.passed -eq $false) { 'FAILING' } else { 'Unknown' }
                }
            })
            if ($rows) { $rows | Format-Table -AutoSize | Out-Host } else { Write-Warning "No usable SMART data." }
        } else { Write-Warning "smartctl scan found no devices." }
    } else {
        if (Get-Command lsblk -ErrorAction SilentlyContinue) {
            & lsblk -d -o NAME,SIZE,TYPE,MODEL 2>$null | Out-Host
        } else {
            Write-Warning "Storage section skipped -- smartmontools not available."
        }
    }

    # -- RAM ------------------------------------------------------------------
    Write-SectionHeader 'Memory (RAM)'
    $mi = @{}
    if (Test-Path '/proc/meminfo') {
        Get-Content '/proc/meminfo' | ForEach-Object {
            if ($_ -match '^(\w+):\s+(\d+)') { $mi[$Matches[1]] = [long]$Matches[2] }
        }
    }
    if ($mi['MemTotal']) {
        $buffCache = ($mi['Buffers'] ?? 0) + ($mi['Cached'] ?? 0) + ($mi['SReclaimable'] ?? 0)
        [PSCustomObject]@{
            'Total (GB)'      = [Math]::Round($mi['MemTotal']                              / 1MB, 2)
            'Used (GB)'       = [Math]::Round(($mi['MemTotal'] - $mi['MemAvailable'])      / 1MB, 2)
            'Available (GB)'  = [Math]::Round($mi['MemAvailable']                          / 1MB, 2)
            'Buff/Cache (GB)' = [Math]::Round($buffCache                                   / 1MB, 2)
            'Swap Total (GB)' = [Math]::Round($mi['SwapTotal']                             / 1MB, 2)
            'Swap Used (GB)'  = [Math]::Round(($mi['SwapTotal'] - $mi['SwapFree'])         / 1MB, 2)
        } | Format-List | Out-Host
    } elseif (Get-Command free -ErrorAction SilentlyContinue) {
        & free -h 2>$null | Out-Host
    } else {
        Write-Warning "RAM information not available."
    }

    # -- Sensors --------------------------------------------------------------
    # Straight from the kernel's hwmon class -- the same source lm-sensors reads,
    # so no package needs to be installed.
    Write-SectionHeader 'Sensors (Temperatures)'
    $hwmonRoot = '/sys/class/hwmon'
    $readings  = @(
        if (Test-Path $hwmonRoot) {
            foreach ($chip in Get-ChildItem $hwmonRoot -ErrorAction SilentlyContinue) {
                $chipName = try { (Get-Content (Join-Path $chip.FullName 'name') -Raw -ErrorAction Stop).Trim() }
                            catch { $chip.Name }
                foreach ($sensor in Get-ChildItem $chip.FullName -Filter 'temp*_input' -ErrorAction SilentlyContinue) {
                    $milli = try { [double](Get-Content $sensor.FullName -Raw -ErrorAction Stop) } catch { continue }
                    $labelFile = $sensor.FullName -replace '_input$', '_label'
                    $label = if (Test-Path $labelFile) {
                        (Get-Content $labelFile -Raw -ErrorAction SilentlyContinue).Trim()
                    } else { $sensor.Name -replace '_input$', '' }
                    [PSCustomObject]@{
                        Chip       = $chipName
                        Sensor     = $label
                        'Temp (C)' = [Math]::Round($milli / 1000, 1)
                    }
                }
            }
        }
    )
    if ($readings) {
        $readings | Sort-Object Chip, Sensor | Format-Table -AutoSize | Out-Host
    } else {
        Write-Warning "No temperature sensors exposed under $hwmonRoot."
    }

} else {
    # -- CPU (Windows) --------------------------------------------------------
    $cpuData = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue
    if ($cpuData) {
        Write-SectionHeader 'CPU Information'
        $cpuData | Select-Object @{N='CPU Name';E={$_.Name}},
                                  @{N='Cores';E={$_.NumberOfCores}},
                                  @{N='Threads';E={$_.NumberOfLogicalProcessors}},
                                  @{N='Base Speed (MHz)';E={$_.MaxClockSpeed}} |
                  Format-Table -AutoSize | Out-Host
    } else { Write-Warning "CPU information not available." }

    # -- GPU (Windows) --------------------------------------------------------
    function ConvertTo-VramGB {
        param($raw)
        if ($null -eq $raw) { return $null }
        $bytes = if ($raw -is [byte[]] -and $raw.Length -ge 8) {
            [BitConverter]::ToInt64($raw, 0)
        } elseif ($raw -isnot [byte[]]) { [long]$raw } else { 0L }
        if ($bytes -le 0) { return $null }
        return [Math]::Round($bytes / 1GB, 2)
    }

    $classKey    = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    $regAdapters = @()
    try {
        $regAdapters = @(
            Get-ChildItem $classKey -ErrorAction SilentlyContinue |
                Where-Object { $_.PSChildName -match '^\d' } |
                ForEach-Object { Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue } |
                Where-Object { $null -ne (ConvertTo-VramGB $_.'HardwareInformation.qwMemorySize') }
        )
    } catch { Write-Warning "Registry adapter key unreadable -- falling back to AdapterRAM: $_" }

    $gpuData = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
    if ($gpuData) {
        Write-SectionHeader 'GPU Information'
        $gpuData | ForEach-Object {
            $gpu      = $_
            $regEntry = $regAdapters | Where-Object { $_.'HardwareInformation.AdapterString' -eq $gpu.Name } | Select-Object -First 1
            if (-not $regEntry) {
                $regEntry = $regAdapters | Where-Object {
                    $a = $_.'HardwareInformation.AdapterString'
                    $a -and ($gpu.Name -like "*$a*" -or $a -like "*$($gpu.Name)*")
                } | Select-Object -First 1
            }
            if (-not $regEntry -and $regAdapters.Count -eq 1) { $regEntry = $regAdapters[0] }

            $vramGB = if ($regEntry) { ConvertTo-VramGB $regEntry.'HardwareInformation.qwMemorySize' }
                      elseif ($gpu.AdapterRAM -ge 1GB) { [Math]::Round($gpu.AdapterRAM / 1GB, 2) }
                      else { 'Shared' }

            [PSCustomObject]@{
                Name          = $gpu.Name
                'Video Proc.' = $gpu.VideoProcessor
                'Driver Ver.' = $gpu.DriverVersion
                'Driver Date' = if ($gpu.DriverDate) { $gpu.DriverDate.ToString('yyyy-MM-dd') } else { 'N/A' }
                'VRAM (GB)'   = $vramGB
            }
        } | Format-Table -AutoSize | Out-Host
    } else { Write-Warning "GPU information not available." }

    # -- Storage (Windows) ----------------------------------------------------
    Write-SectionHeader 'Storage'
    if ($smartctl) {
        $scanData = (& $smartctl --scan --json 2>$null) | ConvertFrom-Json -ErrorAction SilentlyContinue
        $devices  = $scanData.devices
        if ($devices) {
            $storageRows = @(foreach ($dev in $devices) {
                $data = (& $smartctl -a $dev.name --json 2>$null) | ConvertFrom-Json -ErrorAction SilentlyContinue
                if (-not $data -or -not $data.model_name) { continue }
                $busType   = switch ($dev.type) { 'nvme' { 'NVMe' } 'sat' { 'SATA' } default { $dev.type.ToUpper() } }
                $mediaType = if ($dev.type -eq 'nvme') { 'SSD' } elseif ($data.rotation_rate -gt 0) { 'HDD' } else { 'SSD' }
                $lifeLeft = 'N/A'
                if ($dev.type -eq 'nvme') {
                    $pct = $data.nvme_smart_health_information_log.percentage_used
                    if ($null -ne $pct) { $lifeLeft = "$([Math]::Max(0,100-[int]$pct))%" }
                } elseif ($mediaType -eq 'SSD') {
                    $attr = $data.ata_smart_attributes.table | Where-Object { $_.id -in @(231,202,177) } | Select-Object -First 1
                    if ($attr) { $lifeLeft = "$($attr.value)%" }
                }
                [PSCustomObject]@{
                    Model       = $data.model_name
                    Bus         = $busType
                    Type        = $mediaType
                    'Size (GB)' = if ($data.capacity.bytes) { [Math]::Round($data.capacity.bytes/1GB,0) } else { 'N/A' }
                    'Temp (degC)' = if ($null -ne $data.temperature.current) { $data.temperature.current } else { 'N/A' }
                    Hours       = if ($data.power_on_time.hours) { $data.power_on_time.hours } else { 'N/A' }
                    'Life Left' = $lifeLeft
                    Health      = if ($data.smart_status.passed -eq $true) { 'Healthy' } elseif ($data.smart_status.passed -eq $false) { 'FAILING' } else { 'Unknown' }
                }
            })
            if ($storageRows) { $storageRows | Format-Table -AutoSize | Out-Host } else { Write-Warning "smartctl returned no usable device data." }
        } else { Write-Warning "smartctl scan found no devices." }
    } else { Write-Warning "Storage section skipped -- smartmontools not available." }

    # -- RAM (Windows) --------------------------------------------------------
    function Resolve-RamManufacturer {
        param([string]$Manufacturer, [string]$PartNumber)
        $m = $Manufacturer.Trim()
        if ($m -and $m -ne 'Unknown') { return $m }
        switch -Wildcard ($PartNumber.Trim()) {
            'CM*'  { return 'Corsair' }   'CT*'  { return 'Crucial' }
            'BL*'  { return 'Crucial' }   'KVR*' { return 'Kingston' }
            'HX*'  { return 'HyperX / Kingston' }
            'F4-*' { return 'G.Skill' }   'F5-*' { return 'G.Skill' }
            'TED*' { return 'TeamGroup' } 'TEAMGROUP*' { return 'TeamGroup' }
            'MTA*' { return 'Micron' }    'MT*'  { return 'Micron' }
            'M378*'{ return 'Samsung' }   'M471*'{ return 'Samsung' }
            'AD4*' { return 'ADATA' }     'AX4*' { return 'ADATA (XPG)' }
            default { return 'Unknown' }
        }
    }

    $ramData = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue
    if ($ramData) {
        Write-SectionHeader 'Memory (RAM) Modules'
        $ramData | Select-Object @{N='Slot';E={$_.BankLabel}},
                                  @{N='Capacity(GB)';E={[Math]::Round($_.Capacity/1GB,2)}},
                                  @{N='Speed(MT/s)';E={$_.Speed}},
                                  @{N='Part Number';E={$_.PartNumber.Trim()}},
                                  @{N='Manufacturer';E={Resolve-RamManufacturer $_.Manufacturer $_.PartNumber}} |
                   Format-Table -AutoSize | Out-Host
        $totalGB = [Math]::Round(($ramData | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
        Write-Host "Total Installed RAM: $totalGB GB`n" -ForegroundColor Green
    } else { Write-Warning "RAM information not available." }

    # -- Chipset (Windows) ----------------------------------------------------
    Write-SectionHeader 'Chipset'
    $smbus = Get-PnpDevice -Class System -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -like '*SMBus*' -and $_.Status -eq 'OK' } |
        Select-Object -First 1

    if ($smbus) {
        $chipsetVer  = (Get-PnpDeviceProperty -InstanceId $smbus.InstanceId `
                            -KeyName 'DEVPKEY_Device_DriverVersion' -ErrorAction SilentlyContinue).Data
        $chipsetDate = (Get-PnpDeviceProperty -InstanceId $smbus.InstanceId `
                            -KeyName 'DEVPKEY_Device_DriverDate' -ErrorAction SilentlyContinue).Data
        [PSCustomObject]@{
            Device           = $smbus.FriendlyName
            'Driver Version' = if ($chipsetVer)  { $chipsetVer } else { 'N/A' }
            'Driver Date'    = if ($chipsetDate) { ([datetime]$chipsetDate).ToString('yyyy-MM-dd') } else { 'N/A' }
        } | Format-List | Out-Host
    } else { Write-Warning "Chipset SMBus controller not found." }
}
