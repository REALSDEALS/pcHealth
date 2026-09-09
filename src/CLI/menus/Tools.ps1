# ============================================================================
# pcHealth -- Shared -- Tools Menu
# Data-driven: options are filtered per platform at runtime so option numbers
# are always sequential with no gaps.
# ============================================================================

function Show-ToolsMenu {
    # Each entry: Label, Script (relative to tools/), Note, Platforms.
    # Platforms controls which OS sees the option. NeedsMutableOS hides an entry
    # on image-based systems (Silverblue, Bazzite, MicroOS), where /usr is
    # read-only and the bootloader belongs to the deployment.
    $toolDefs = @(
        @{ Label = 'System Information';          Script = 'Get-SystemInfo.ps1';          Note = '';                      Platforms = @('Windows','Linux') }
        @{ Label = 'Hardware Information';         Script = 'Get-HardwareInfo.ps1';         Note = '';                      Platforms = @('Windows','Linux') }
        @{ Label = 'Scan + Repair';                Script = 'Invoke-ScanAndRepair.ps1';      Note = '(SFC + DISM combined)'; Platforms = @('Windows') }
        @{ Label = 'Battery Report';               Script = 'Get-BatteryReport.ps1';         Note = '(laptop only)';         Platforms = @('Windows') }
        @{ Label = 'Windows Update';               Script = 'Invoke-WindowsUpdate.ps1';      Note = '';                      Platforms = @('Windows') }
        @{ Label = 'Disk Optimization';            Script = 'Invoke-DiskOptimize.ps1';       Note = '';                      Platforms = @('Windows') }
        @{ Label = 'Disk Cleanup';                 Script = 'Invoke-DiskCleanup.ps1';        Note = '';                      Platforms = @('Windows') }
        @{ Label = 'Short Ping Test';              Script = 'Test-NetworkShort.ps1';         Note = '';                      Platforms = @('Windows','Linux') }
        @{ Label = 'Continuous Ping Test';         Script = 'Test-NetworkContinuous.ps1';    Note = '';                      Platforms = @('Windows','Linux') }
        @{ Label = 'Traceroute to Google';         Script = 'Test-Traceroute.ps1';           Note = '';                      Platforms = @('Windows','Linux') }
        @{ Label = 'Reset Network Stack';          Script = 'Invoke-NetworkReset.ps1';       Note = '';                      Platforms = @('Windows') }
        @{ Label = 'Update all packages';          Script = 'Invoke-SystemUpdate.ps1';       Note = '(winget)';              Platforms = @('Windows') }
        @{ Label = 'Update HP Drivers';            Script = 'Invoke-HPUpdate.ps1';           Note = '(HP only)';             Platforms = @('Windows') }
        @{ Label = 'Restart Audio Drivers';        Script = 'Invoke-AudioRestart.ps1';       Note = '';                      Platforms = @('Windows') }
        @{ Label = 'Open Battery Report';          Script = 'Open-BatteryReport.ps1';        Note = '';                      Platforms = @('Windows') }
        @{ Label = 'Open CBS Log';                 Script = 'Open-CBSLog.ps1';               Note = '';                      Platforms = @('Windows') }
        @{ Label = 'Get Ninite';                   Script = 'Get-Ninite.ps1';                Note = '(Edge, Chrome, VLC, 7-Zip)'; Platforms = @('Windows') }
        @{ Label = 'Windows License Key';          Script = 'Get-LicenseKey.ps1';            Note = '';                      Platforms = @('Windows') }
        @{ Label = 'BIOS Password Recovery';       Script = 'Open-BIOSPasswordTool.ps1';     Note = '';                      Platforms = @('Windows','Linux') }
        @{ Label = 'Boot Repair';                  Script = 'Invoke-BootRepair.ps1';         Note = '(UEFI - caution!)';     Platforms = @('Windows') }
        @{ Label = 'Shutdown / Reboot / Log Off';  Script = 'Invoke-PowerOptions.ps1';       Note = '';                      Platforms = @('Windows','Linux') }
        @{ Label = 'Repair Winget';                Script = 'Invoke-WingetRepair.ps1';       Note = '';                      Platforms = @('Windows') }
        @{ Label = 'Update all packages';          Script = 'linux/Invoke-SystemUpdate.ps1';  Note = '(apt / dnf / pacman / zypper)';   Platforms = @('Linux'); NeedsMutableOS = $true }
        @{ Label = 'Topgrade';                     Script = 'linux/Invoke-Topgrade.ps1';       Note = '(full system upgrade)';           Platforms = @('Linux') }
        @{ Label = 'Battery Report';               Script = 'linux/Get-BatteryReport.ps1';     Note = '(laptop only)';                   Platforms = @('Linux') }
        @{ Label = 'Scan + Repair';                Script = 'linux/Invoke-ScanAndRepair.ps1';  Note = '(package integrity)';             Platforms = @('Linux'); NeedsMutableOS = $true }
        @{ Label = 'Disk Optimization';            Script = 'linux/Invoke-DiskOptimize.ps1';   Note = '(SSD trim)';                      Platforms = @('Linux') }
        @{ Label = 'Firmware Update';              Script = 'linux/Invoke-FirmwareUpdate.ps1'; Note = '(fwupd / LVFS)';                  Platforms = @('Linux') }
        @{ Label = 'Boot Repair';                  Script = 'linux/Invoke-BootRepair.ps1';     Note = '(UEFI - caution!)';               Platforms = @('Linux'); NeedsMutableOS = $true }
        @{ Label = 'Disk Cleanup';                 Script = 'linux/Invoke-DiskCleanup.ps1';   Note = '(cache, journal, flatpak)';       Platforms = @('Linux'); NeedsMutableOS = $true }
        @{ Label = 'Restart Audio';                Script = 'linux/Invoke-AudioRestart.ps1';  Note = '(PipeWire / PulseAudio)';         Platforms = @('Linux') }
        @{ Label = 'Reset Network Stack';          Script = 'linux/Invoke-NetworkReset.ps1';  Note = '';                                Platforms = @('Linux') }
        @{ Label = 'View System Logs';             Script = 'linux/Get-SystemLogs.ps1';       Note = '(journalctl)';                    Platforms = @('Linux') }
    )

    $active = @($toolDefs | Where-Object {
        $_.Platforms -contains $Global:PcPlatform -and
        -not ($_.NeedsMutableOS -and $Global:PcImageBased)
    })
    $t      = Join-Path $Global:pcHealthRoot 'tools'

    while ($true) {
        Set-PcTheme 'Tools'
        Clear-PcHost
        Write-PcHeader 'Tools'

        for ($i = 1; $i -le $active.Count; $i++) {
            Write-PcOption "$i" $active[$i - 1].Label $active[$i - 1].Note
        }

        $nav1 = $active.Count + 1
        $nav2 = $active.Count + 2
        $nav3 = $active.Count + 3

        Write-PcDivider
        Write-PcOption "$nav1" 'Programs Menu'
        Write-PcOption "$nav2" 'Back to Main Menu'
        Write-PcOption "$nav3" 'Exit'
        Write-PcDivider

        $choice = (Read-Host "`n  Choice").Trim()

        $num = 0
        if (-not [int]::TryParse($choice, [ref]$num)) {
            Write-Host "`n  Invalid choice." -ForegroundColor Red
            Start-Sleep -Milliseconds 800
            continue
        }

        if ($num -ge 1 -and $num -le $active.Count) {
            $entry = $active[$num - 1]
            Set-PcTheme 'Action'
            Clear-PcHost
            try {
                & (Join-Path $t $entry.Script)
            } catch [System.Management.Automation.PipelineStoppedException] {
                Write-Debug 'Tool stopped via Ctrl+C, returning to menu.'
            } catch {
                Write-Host "`n[!!] Tool error: $_`n" -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
            $nav = Read-PcNavChoice 'Back to Tools Menu'
            switch ($nav) {
                '2' { return 'main' }
                '3' { return 'exit' }
            }
        } elseif ($num -eq $nav1) { return 'programs'
        } elseif ($num -eq $nav2) { return 'main'
        } elseif ($num -eq $nav3) { return 'exit'
        } else {
            Write-Host "`n  Invalid choice." -ForegroundColor Red
            Start-Sleep -Milliseconds 800
        }
    }
}
