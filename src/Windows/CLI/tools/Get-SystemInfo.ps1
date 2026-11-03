#Requires -Version 7.0
# ============================================================================
# pcHealth -- System Information
# ============================================================================

$os    = Get-CimInstance -ClassName Win32_OperatingSystem
$cs    = Get-CimInstance -ClassName Win32_ComputerSystem
$cpu   = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$ntCv  = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue

$winVer    = $ntCv.DisplayVersion
$ubr       = $ntCv.UBR
$fullBuild = if ($ubr) { "$($os.BuildNumber).$ubr" } else { $os.BuildNumber }

$fw        = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
$fwType    = switch (Get-PcFirmwareType) { 'UEFI' { 'UEFI' } 'BIOS' { 'Legacy BIOS' } default { 'Unknown' } }
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
