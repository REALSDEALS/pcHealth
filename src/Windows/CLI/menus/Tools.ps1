# ============================================================================
# pcHealth -- Windows -- Tools Menu
# Data-driven: the catalogue below mirrors assets/tools.json, which the Linux
# app reads as well. Keep the two in step when adding a tool.
# ============================================================================

function Show-ToolsMenu {
    # Each entry: Label, Script (relative to tools/), Note.
    $toolDefs = @(
        @{ Label = 'System Information';          Script = 'Get-SystemInfo.ps1';          Note = '' }
        @{ Label = 'Hardware Information';         Script = 'Get-HardwareInfo.ps1';         Note = '' }
        @{ Label = 'Scan + Repair';                Script = 'Invoke-ScanAndRepair.ps1';      Note = '(SFC + DISM combined)' }
        @{ Label = 'Battery Report';               Script = 'Get-BatteryReport.ps1';         Note = '(laptop only)' }
        @{ Label = 'Windows Update';               Script = 'Invoke-WindowsUpdate.ps1';      Note = '' }
        @{ Label = 'Disk Optimization';            Script = 'Invoke-DiskOptimize.ps1';       Note = '' }
        @{ Label = 'Disk Cleanup';                 Script = 'Invoke-DiskCleanup.ps1';        Note = '' }
        @{ Label = 'Short Ping Test';              Script = 'Test-NetworkShort.ps1';         Note = '' }
        @{ Label = 'Continuous Ping Test';         Script = 'Test-NetworkContinuous.ps1';    Note = '' }
        @{ Label = 'Traceroute to Google';         Script = 'Test-Traceroute.ps1';           Note = '' }
        @{ Label = 'Reset Network Stack';          Script = 'Invoke-NetworkReset.ps1';       Note = '' }
        @{ Label = 'Update all packages';          Script = 'Invoke-SystemUpdate.ps1';       Note = '(winget)' }
        @{ Label = 'Update HP Drivers';            Script = 'Invoke-HPUpdate.ps1';           Note = '(HP only)' }
        @{ Label = 'Restart Audio Drivers';        Script = 'Invoke-AudioRestart.ps1';       Note = '' }
        @{ Label = 'Open Battery Report';          Script = 'Open-BatteryReport.ps1';        Note = '' }
        @{ Label = 'Open CBS Log';                 Script = 'Open-CBSLog.ps1';               Note = '' }
        @{ Label = 'Get Ninite';                   Script = 'Get-Ninite.ps1';                Note = '(Edge, Chrome, VLC, 7-Zip)' }
        @{ Label = 'Windows License Key';          Script = 'Get-LicenseKey.ps1';            Note = '' }
        @{ Label = 'BIOS Password Recovery';       Script = 'Open-BIOSPasswordTool.ps1';     Note = '' }
        @{ Label = 'Boot Repair';                  Script = 'Invoke-BootRepair.ps1';         Note = '(UEFI - caution!)' }
        @{ Label = 'Shutdown / Reboot / Log Off';  Script = 'Invoke-PowerOptions.ps1';       Note = '' }
        @{ Label = 'Repair Winget';                Script = 'Invoke-WingetRepair.ps1';       Note = '' }
    )

    $active = @($toolDefs)
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
