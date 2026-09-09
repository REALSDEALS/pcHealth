# ============================================================================
# pcHealth -- Shared -- Programs Menu
# Windows: installs via winget. Linux: installs via the distro package manager.
# ============================================================================

# Translates a winget exit code into a human-readable message.
# Source: https://github.com/microsoft/winget-cli/blob/master/doc/windows/package-manager/winget/returnCodes.md
function Get-WingetResult {
    param([int]$ExitCode)

    $hex = '0x{0:X8}' -f ([System.BitConverter]::ToUInt32([System.BitConverter]::GetBytes([int32]$ExitCode), 0))

    $info = @{
        '0x8A15002B' = 'No applicable update found (already up to date).'
        '0x8A15004F' = 'A newer or equal version is already installed.'
        '0x8A150050' = 'Upgrade version is unknown.'
        '0x8A150061' = 'Package is already installed.'
        '0x8A150068' = 'Package is pinned and cannot be upgraded.'
        '0x8A150101' = 'Application is currently running. Close it and try again.'
        '0x8A150102' = 'Another installation is already in progress. Try again later.'
        '0x8A150103' = 'A file is in use. Close the application and try again.'
        '0x8A150104' = 'A required dependency is missing.'
        '0x8A150105' = 'Not enough disk space. Free up space and try again.'
        '0x8A150106' = 'Not enough memory available. Close other applications and try again.'
        '0x8A150107' = 'No internet connection. Connect to a network and try again.'
        '0x8A150109' = 'Restart your PC to finish installation.'
        '0x8A15010A' = 'Restart your PC and try again.'
        '0x8A15010B' = 'Your PC will restart to finish installation.'
        '0x8A15010C' = 'Installation cancelled.'
        '0x8A15010D' = 'Another version of this application is already installed.'
        '0x8A15010E' = 'A higher version is already installed.'
        '0x8A15010F' = 'Installation is blocked by organisation policy. Contact your admin.'
        '0x8A150056' = 'This installer cannot run from an administrator context.'
        '0x8A150114' = 'The installer does not support upgrading an existing package.'
    }

    $broken = @{
        '0x8A150001' = 'Internal error.'
        '0x8A150003' = 'Executing command failed.'
        '0x8A150008' = 'Download failed.'
        '0x8A15000A' = 'The package index is corrupt.'
        '0x8A15000B' = 'The configured source information is corrupt.'
        '0x8A15000F' = 'Data required by the source is missing.'
        '0x8A150011' = 'Installer hash mismatch -- the download may be corrupt.'
        '0x8A150014' = 'No packages found. The source may be unavailable.'
        '0x8A150015' = 'No sources are configured.'
        '0x8A150037' = 'Source configuration error.'
        '0x8A150038' = 'The configured source is not supported.'
        '0x8A150039' = 'Invalid data returned by source.'
        '0x8A15003F' = 'The source data is corrupted or tampered.'
        '0x8A150045' = 'Failed to open the source.'
        '0x8A15004B' = 'Failed to open one or more sources.'
        '0x8A150086' = 'Downloaded a zero-byte installer. Check your network connection.'
    }

    if ($ExitCode -eq 0) { return @{ Ok = $true;  Message = 'Successfully installed.'; SuggestRepair = $false } }
    if ($info.ContainsKey($hex))   { return @{ Ok = $false; Message = $info[$hex];   SuggestRepair = $false } }
    if ($broken.ContainsKey($hex)) { return @{ Ok = $false; Message = $broken[$hex]; SuggestRepair = $true  } }
    return @{ Ok = $false; Message = "Unexpected exit code ($hex)."; SuggestRepair = $true }
}

function Show-ProgramsMenu {
    if ($Global:PcPlatform -eq 'Linux') {
        Show-LinuxProgramsMenu
    } else {
        Show-WindowsProgramsMenu
    }
}

function Get-InstalledApp {
    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($p in $regPaths) {
        Get-ItemProperty $p -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName }
    }
}

function Resolve-AppExePath {
    param($RegEntry, [string]$ExeName)
    if ($RegEntry.InstallLocation) {
        $candidate = Join-Path $RegEntry.InstallLocation.TrimEnd('\/') $ExeName
        if (Test-Path $candidate) { return $candidate }
    }
    if ($RegEntry.DisplayIcon) {
        $iconPath = ($RegEntry.DisplayIcon -split ',')[0].Trim('"')
        if ($iconPath -like '*.exe' -and (Test-Path $iconPath)) { return $iconPath }
    }
    return $null
}

function Show-WindowsProgramsMenu {
    $packages = [ordered]@{
        '1' = @{ Name = 'HWiNFO64';                Id = 'REALix.HWiNFO';                   ExeName = 'HWiNFO64.exe';   RegistryName = 'HWiNFO'         }
        '2' = @{ Name = 'HWMonitor';               Id = 'CPUID.HWMonitor';                 ExeName = 'HWMonitor.exe';  RegistryName = 'HWMonitor'       }
        '3' = @{ Name = 'Malwarebytes AdwCleaner';  Id = 'Malwarebytes.AdwCleaner';         ExeName = 'AdwCleaner.exe'; RegistryName = 'AdwCleaner'      }
        '4' = @{ Name = 'CrystalDiskInfo';          Id = 'CrystalDewWorld.CrystalDiskInfo'; ExeName = 'DiskInfo64.exe'; RegistryName = 'CrystalDiskInfo' }
        '5' = @{ Name = 'CrystalDiskMark';          Id = 'CrystalDewWorld.CrystalDiskMark'; ExeName = 'DiskMark64.exe'; RegistryName = 'CrystalDiskMark' }
        '6' = @{ Name = 'Prime95';                  Id = 'mersenne.prime95';               ExeName = 'prime95.exe';    RegistryName = 'Prime95'         }
        '7' = @{ Name = 'Windows PowerToys';        Id = 'Microsoft.PowerToys';            ExeName = 'PowerToys.exe';  RegistryName = 'PowerToys'       }
    }

    $allApps = @(Get-InstalledApp)
    $status  = @{}
    foreach ($key in $packages.Keys) {
        $entry = $allApps | Where-Object { $_.DisplayName -like "*$($packages[$key].RegistryName)*" } | Select-Object -First 1
        if ($entry) {
            $status[$key] = @{ Installed = $true; ExePath = Resolve-AppExePath $entry $packages[$key].ExeName }
        } else {
            $status[$key] = @{ Installed = $false; ExePath = $null }
        }
    }

    while ($true) {
        Set-PcTheme 'Programs'
        Clear-PcHost
        Write-PcHeader 'Programs'

        foreach ($key in $packages.Keys) {
            $note = if ($status[$key].Installed) { '[installed]' } else { '' }
            Write-PcOption $key $packages[$key].Name $note
        }
        Write-PcDivider
        Write-PcOption '8'  'Tools Menu'
        Write-PcOption '9'  'Back to Main Menu'
        Write-PcOption '10' 'Exit'
        Write-PcDivider

        $choice = (Read-Host "`n  Choice").Trim()

        switch ($choice) {
            '8'  { return 'tools' }
            '9'  { return 'main'  }
            '10' { return 'exit'  }
        }

        if ($packages.Contains($choice)) {
            $pkg = $packages[$choice]
            $s   = $status[$choice]

            if ($s.Installed) {
                Set-PcTheme 'Action'
                Clear-PcHost
                Write-PcHeader 'Programs'
                Write-Host "  $($pkg.Name) is already installed.`n"
                Write-PcDivider
                Write-PcOption '1' 'Update'
                Write-PcOption '2' 'Open'
                Write-PcOption '3' 'Back'
                Write-PcDivider

                $action = (Read-Host "`n  Choice").Trim()
                switch ($action) {
                    '1' {
                        Clear-PcHost
                        Write-Host "[>>] Checking for updates for $($pkg.Name)...`n" -ForegroundColor Yellow
                        $proc   = Start-Process winget `
                            -ArgumentList "upgrade --id $($pkg.Id) --accept-source-agreements --accept-package-agreements" `
                            -Wait -PassThru -NoNewWindow
                        $result = Get-WingetResult $proc.ExitCode
                        if ($result.Ok) {
                            Write-Host "`n[OK] $($pkg.Name) updated." -ForegroundColor Green
                        } else {
                            $color = if ($result.SuggestRepair) { 'Red' } else { 'Yellow' }
                            Write-Host "`n[..] $($result.Message)" -ForegroundColor $color
                        }
                        $nav = Read-PcNavChoice 'Back to Programs Menu'
                        switch ($nav) {
                            '2' { return 'main' }
                            '3' { return 'exit' }
                        }
                    }
                    '2' {
                        $exePath = $s.ExePath
                        if (-not $exePath) {
                            $appReg  = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$($pkg.ExeName)" -ErrorAction SilentlyContinue
                            $exePath = if ($appReg) { $appReg.'(default)' } else { $pkg.ExeName }
                        }
                        try {
                            if (Test-Path $exePath) { Start-Process -FilePath $exePath }
                            else { Start-Process -FilePath $pkg.ExeName }
                        }
                        catch { Write-Host "`n  [!!] Cannot open $($pkg.Name): $_" -ForegroundColor Red; Start-Sleep 2 }
                    }
                    # '3' or anything else: fall through back to menu
                }
            } else {
                Set-PcTheme 'Action'
                Clear-PcHost
                Write-Host "[>>] Installing $($pkg.Name)...`n" -ForegroundColor Yellow

                $proc = Start-Process winget `
                    -ArgumentList "install --id $($pkg.Id) --accept-source-agreements --accept-package-agreements" `
                    -Wait -PassThru -NoNewWindow

                $result = Get-WingetResult $proc.ExitCode
                if ($result.Ok) {
                    Write-Host "`n[OK] $($pkg.Name) installed." -ForegroundColor Green
                    $allApps = @(Get-InstalledApp)
                    $entry   = $allApps | Where-Object { $_.DisplayName -like "*$($pkg.RegistryName)*" } | Select-Object -First 1
                    if ($entry) {
                        $status[$choice] = @{ Installed = $true; ExePath = Resolve-AppExePath $entry $pkg.ExeName }
                    }
                } else {
                    $color = if ($result.SuggestRepair) { 'Red' } else { 'Yellow' }
                    Write-Host "`n[!!] $($result.Message)" -ForegroundColor $color
                    if ($result.SuggestRepair) {
                        Write-Host "     Tip: try 'Repair Winget' in the Tools menu." -ForegroundColor DarkGray
                    }
                }

                $nav = Read-PcNavChoice 'Back to Programs Menu'
                switch ($nav) {
                    '2' { return 'main' }
                    '3' { return 'exit' }
                }
            }
        } else {
            Write-Host "`n  Invalid choice." -ForegroundColor Red
            Start-Sleep -Milliseconds 800
        }
    }
}

function Show-LinuxProgramsMenu {
    $pm = Get-PcPackageManager

    # Bin is what the menu probes for the [installed] marker: one PATH lookup,
    # instead of a different "is this package present" query per manager.
    $packages = [ordered]@{
        '1' = @{ Name = 'htop';          Pkg = 'htop';          Bin = 'htop';      Note = '(process viewer)'  }
        '2' = @{ Name = 'iotop';         Pkg = 'iotop';         Bin = 'iotop';     Note = '(I/O monitor)'     }
        '3' = @{ Name = 'smartmontools'; Pkg = 'smartmontools'; Bin = 'smartctl';  Note = '(disk SMART data)' }
        '4' = @{ Name = 'stress-ng';     Pkg = 'stress-ng';     Bin = 'stress-ng'; Note = '(stress test)'     }
        '5' = @{ Name = 'nmap';          Pkg = 'nmap';          Bin = 'nmap';      Note = '(network scanner)' }
    }

    $navTools = $packages.Count + 1
    $navMain  = $packages.Count + 2
    $navExit  = $packages.Count + 3

    while ($true) {
        Set-PcTheme 'Programs'
        Clear-PcHost
        Write-PcHeader 'Programs'

        if ($Global:PcImageBased) {
            Write-Host '  Image-based system: pcHealth does not install packages here.' -ForegroundColor DarkGray
            Write-Host "  Use Homebrew or a Distrobox container instead.`n" -ForegroundColor DarkGray
        } elseif ($pm) {
            Write-Host "  Package manager: $($pm.Cmd)`n" -ForegroundColor DarkGray
        } else {
            Write-Host "  [!] No supported package manager found (apt/dnf/pacman/zypper).`n" -ForegroundColor Yellow
        }

        foreach ($key in $packages.Keys) {
            $p    = $packages[$key]
            $note = if (Get-Command $p.Bin -CommandType Application -ErrorAction SilentlyContinue) {
                "$($p.Note)  [installed]"
            } else { $p.Note }
            Write-PcOption $key $p.Name $note
        }

        Write-PcDivider
        Write-PcOption "$navTools" 'Tools Menu'
        Write-PcOption "$navMain"  'Back to Main Menu'
        Write-PcOption "$navExit"  'Exit'
        Write-PcDivider

        $choice = (Read-Host "`n  Choice").Trim()

        switch ($choice) {
            "$navTools" { return 'tools' }
            "$navMain"  { return 'main'  }
            "$navExit"  { return 'exit'  }
        }

        if (-not $packages.Contains($choice)) {
            Write-Host "`n  Invalid choice." -ForegroundColor Red
            Start-Sleep -Milliseconds 800
            continue
        }

        $pkg = $packages[$choice]
        Set-PcTheme 'Action'
        Clear-PcHost

        if (Get-Command $pkg.Bin -CommandType Application -ErrorAction SilentlyContinue) {
            Write-Host "[OK] $($pkg.Name) is already installed." -ForegroundColor Green
            Write-Host "     Update it via Tools > Update all packages.`n" -ForegroundColor DarkGray
        } elseif ($Global:PcImageBased -or -not $pm) {
            Write-Host '[!!] pcHealth does not install packages on an image-based system.' -ForegroundColor Red
            Write-Host "     Install $($pkg.Name) with Homebrew or inside a Distrobox container.`n" -ForegroundColor Yellow
        } else {
            Write-Host "[>>] Installing $($pkg.Name) via $($pm.Cmd)...`n" -ForegroundColor Yellow
            & $pm.Cmd @($pm.Install) $pkg.Pkg
            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n[OK] $($pkg.Name) installed." -ForegroundColor Green
            } else {
                Write-Host "`n[!!] Installation returned exit code $LASTEXITCODE." -ForegroundColor Red
            }
        }

        $nav = Read-PcNavChoice 'Back to Programs Menu'
        switch ($nav) {
            '2' { return 'main' }
            '3' { return 'exit' }
        }
    }
}
