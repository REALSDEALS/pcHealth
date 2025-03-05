# Powershell-Helper function to get CPU, GPU, and RAM information.
# Reason: Microsoft has deprecated WIMCI and replaced it with Get-CimInstance. Get-CimInstance is not available in batch mode.
# Microsoft is slowly deprecating older Windows components and replacing it with newer ones. You can read more here: https://techcommunity.microsoft.com/blog/windows-itpro-blog/wmi-command-line-wmic-utility-deprecation-next-steps/4039242


[CmdletBinding()]
param()

# -------------------------------
# 1. CPU Information
# -------------------------------
Write-Verbose "Gathering CPU information..."
$cpuData = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue
if (!$cpuData) {
    Write-Warning "CPU information not found."
} else {
    # Select relevant CPU properties and rename for clarity
    $cpuInfo = $cpuData | Select-Object @{Name='CPU Name'; Expression={$_.Name}},
                                   @{Name='Cores'; Expression={$_.NumberOfCores}},
                                   @{Name='Threads'; Expression={$_.NumberOfLogicalProcessors}}
}

# -------------------------------
# 2. GPU Information
# -------------------------------
Write-Verbose "Gathering GPU information..."
# Query the registry for accurate VRAM sizes (handles GPUs with >4GB VRAM)&#8203;:contentReference[oaicite:1]{index=1}
$regPath  = "HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*"
$adapterMemory = Get-ItemProperty -Path $regPath -Name "HardwareInformation.AdapterString", "HardwareInformation.qwMemorySize" -ErrorAction SilentlyContinue

$gpuData = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
if (!$gpuData) {
    Write-Warning "GPU information not found."
} else {
    # Build GPU info objects with corrected VRAM values
    $gpuInfo = foreach ($gpu in $gpuData) {
        # Find matching registry entry by adapter name (if available)
        $regEntry = $null
        if ($adapterMemory) {
            $regEntry = $adapterMemory | Where-Object { $_."HardwareInformation.AdapterString" -eq $gpu.Name }
        }
        # Determine VRAM in GB (use registry value if present; otherwise fall back to AdapterRAM)
        $vramGB = $null
        if ($regEntry -and $regEntry."HardwareInformation.qwMemorySize") {
            $vramGB = [Math]::Round($regEntry."HardwareInformation.qwMemorySize" / 1GB, 2)
        } elseif ($gpu.AdapterRAM) {
            $vramGB = [Math]::Round($gpu.AdapterRAM / 1GB, 2)
        }
        # Output object for this GPU
        [PSCustomObject]@{
            Name           = $gpu.Name
            VideoProcessor = $gpu.VideoProcessor
            DriverVersion  = $gpu.DriverVersion
            "VRAM(GB)"     = if ($vramGB) { $vramGB } else { "N/A" }
        }
    }
}

# -------------------------------
# 3. RAM Information
# -------------------------------
Write-Verbose "Gathering RAM module information..."
$ramData = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue
if (!$ramData) {
    Write-Warning "Memory (RAM) information not found."
} else {
    # Select and format RAM module properties (BankLabel, Capacity in GB, Speed in MHz)
    $ramInfo = $ramData | Select-Object @{Name='BankLabel'; Expression={$_.BankLabel}},
                                   @{Name='Capacity(GB)'; Expression={[Math]::Round($_.Capacity / 1GB, 2)}},
                                   @{Name='Speed(MHz)'; Expression={$_.Speed}}
}

# -------------------------------
# 4. Output (Formatted Tables)
# -------------------------------
# Output results in structured tables with headings
if ($cpuInfo) {
    Write-Host "`nCPU Information:" -ForegroundColor Cyan
    $cpuInfo | Format-Table -AutoSize
}
if ($gpuInfo) {
    Write-Host "`nGPU Information:" -ForegroundColor Cyan
    $gpuInfo | Format-Table -AutoSize
}
if ($ramInfo) {
    Write-Host "`nMemory (RAM) Modules:" -ForegroundColor Cyan
    $ramInfo | Format-Table -AutoSize
}

# -------------------------------
# 5. Total Installed RAM
# -------------------------------
if ($ramData) {
    $totalRAM = ($ramData | Measure-Object -Property Capacity -Sum).Sum
    $totalRAMGB = [Math]::Round($totalRAM / 1GB, 2)
    Write-Host "`nTotal Installed Memory (RAM): $totalRAMGB GB" -ForegroundColor Green
}
