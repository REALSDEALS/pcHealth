# ============================================================================
# pcHealth -- Shared -- Main Menu
# ============================================================================

function Show-MainMenu {
    $target = 'main'

    while ($true) {
        if ($target -eq 'tools') {
            $target = Show-ToolsMenu
        } elseif ($target -eq 'programs') {
            $target = Show-ProgramsMenu
        } elseif ($target -eq 'exit') {
            exit 0
        } else {
            Set-PcTheme 'Main'
            Clear-PcHost
            Write-PcHeader 'Main Menu'

            Write-Host "  Thanks for downloading and using pcHealth!"
            Write-Host "  Made by REALSDEALS - Licensed under GNU-3" -ForegroundColor DarkGray
            Write-Host "  You are now using pcHealth - $Global:PcPlatformLabel - V$Global:PcVersion`n" -ForegroundColor DarkGray
            Write-PcDivider

            Write-PcOption '1' 'Tools'
            Write-PcOption '2' 'Programs'
            Write-PcDivider
            Write-PcOption '3' 'Go to repository'
            Write-PcOption '4' 'Check for pre-releases'
            Write-PcDivider
            Write-PcOption '5' 'Exit'
            Write-PcDivider

            $choice = (Read-Host "`n  Choice").Trim()

            switch ($choice) {
                '1' { $target = 'tools' }
                '2' { $target = 'programs' }
                '3' { Open-PcUrl 'https://github.com/REALSDEALS/pcHealth' }
                '4' { Open-PcUrl 'https://github.com/REALSDEALS/pcHealth/releases' }
                '5' { $target = 'exit' }
                default {
                    Write-Host "`n  Invalid choice." -ForegroundColor Red
                    Start-Sleep -Milliseconds 800
                }
            }
        }
    }
}
