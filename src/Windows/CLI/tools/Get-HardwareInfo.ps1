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
    $prog = "$env:ProgramFiles\smartmontools\bin\smartctl.exe"
    if (Test-Path $prog) { return $prog }
    return $null
}

$smartctl = Find-Smartctl
if (-not $smartctl) {
    Write-Host "`n[pcHealth] smartmontools is recommended for full SMART disk health data (life %, temperature, power-on hours)." -ForegroundColor Yellow
    Write-Host '           Without it, life %, temperature and power-on hours are unavailable.' -ForegroundColor DarkGray

    $answer = (Read-Host '  Install now via winget? [Y/N]').Trim()
    if ($answer -match '^[Yy]') {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Host '[!!] winget not available. Install from: https://www.smartmontools.org/' -ForegroundColor Yellow
        } else {
            winget install --source winget --id smartmontools.smartmontools -e --silent `
                --accept-package-agreements --accept-source-agreements
            $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                        [System.Environment]::GetEnvironmentVariable('Path','User')
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
