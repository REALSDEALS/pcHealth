# Powershell-Helper function to get CPU, GPU, and RAM information.
# Reason: Microsoft has deprecated WIMCI and replaced it with Get-CimInstance. Get-CimInstance is not available in batch mode.
# Microsoft is slowly deprecating older Windows components and replacing it with newer ones. You can read more here: https://techcommunity.microsoft.com/blog/windows-itpro-blog/wmi-command-line-wmic-utility-deprecation-next-steps/4039242


# -------------------------------
# 1. CPU Information
# -------------------------------
$cpuWMI = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
$cpu = foreach ($c in $cpuWMI) {
    [PSCustomObject]@{
        Name                      = $c.Name
        NumberOfCores             = $c.NumberOfCores
        NumberOfLogicalProcessors = $c.NumberOfLogicalProcessors
    }
}

# -------------------------------
# 2. GPU Information
# -------------------------------
$gpuCIM = Get-CimInstance Win32_VideoController |
    Select-Object Name, VideoProcessor, DriverVersion

$tempFile = "$env:TEMP\dxdiag.txt"
dxdiag /t $tempFile | Out-Null

$gpuDX = Get-Content $tempFile | Select-String "Dedicated Memory:" | ForEach-Object {
    if ($_ -match "Dedicated Memory:\s+(\d+)\s*MB") {
        [PSCustomObject]@{
            VRAM_GB = [math]::Round([int]$Matches[1] / 1024, 2)
        }
    }
} | Where-Object { $_.VRAM_GB -gt 0 }

if ($gpuCIM.Count -eq $gpuDX.Count) {
    $gpuInfo = for ($i = 0; $i -lt $gpuCIM.Count; $i++) {
        [PSCustomObject]@{
            Name             = $gpuCIM[$i].Name
            VideoProcessor   = $gpuCIM[$i].VideoProcessor
            DriverVersion    = $gpuCIM[$i].DriverVersion
            DedicatedVRAM_GB = $gpuDX[$i].VRAM_GB
        }
    }
} else {
    $gpuInfo = $gpuCIM
}

# -------------------------------
# 3. RAM Information
# -------------------------------
$ramModules = Get-CimInstance Win32_PhysicalMemory |
    Select-Object BankLabel,
                  @{Name="Capacity(GB)"; Expression={[math]::Round($_.Capacity / 1GB,2)}},
                  @{Name="Speed(MT/s)";  Expression={$_.Speed}}

$slotsUsed = $ramModules.Count
$totalRAM  = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)

# -------------------------------
# 4. Output (Formatted Tables)
# -------------------------------
Write-Host "=== CPU Information ===" -ForegroundColor Cyan
$cpu | Format-Table -AutoSize

Write-Host "`n=== GPU Information ===" -ForegroundColor Cyan
$gpuInfo | Format-Table -AutoSize

Write-Host "`n=== RAM Information ===" -ForegroundColor Cyan
$ramModules | Format-Table -AutoSize
Write-Host "`nRAM Slots Used: $slotsUsed"
Write-Host "Total Physical Memory: $totalRAM GB"
