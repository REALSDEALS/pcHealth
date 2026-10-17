#Requires -Version 5.1
# ============================================================================
# pcHealth -- Windows CLI Launcher
# PS5.1-compatible bootstrap: enforces PS7, admin rights and optional deps.
# Runs under PS5 → installs PS7 if needed → relaunches in PS7.
# On Linux, use src/Linux instead: python3 -m pchealth
# ============================================================================

$ErrorActionPreference = 'Stop'
$isPwsh7 = $PSVersionTable.PSVersion.Major -ge 7

# $IsLinux / $IsMacOS are PS6+ variables; on PS 5.1 they are $null (falsy).
if ($IsLinux -or $IsMacOS) {
    Write-Host '[!!] This is the Windows CLI.' -ForegroundColor Red
    Write-Host '     On Linux, use src/Linux instead: python3 -m pchealth' -ForegroundColor Yellow
    exit 1
}

# -- Build check, elevate, relaunch in PS7 ------------------------------------
# Windows support floors -- see README.md and SECURITY.md.
#   >= 26200  recommended : the build every release is tested on
#   >= 19045  supported   : Windows 10 22H2 and Windows 11
#   <  19045  blocked     : WinUI 3 does not render below 22H2, so the GUI
#                           cannot follow the CLI down and the two floors
#                           are kept identical rather than drifting apart
$recommendedBuild = 26200   # Windows 11 25H2
$hardMinimumBuild = 19045   # Windows 10 22H2
$build = [System.Environment]::OSVersion.Version.Build

if ($build -lt $hardMinimumBuild) {
    Write-Host "[!!] pcHealth cannot run on Windows build $build." -ForegroundColor Red
    Write-Host "     Minimum required: build $hardMinimumBuild (Windows 10 version 22H2)." -ForegroundColor Red
    Write-Host "     https://learn.microsoft.com/en-us/windows/release-health/release-information" -ForegroundColor DarkGray
    Read-Host 'Press Enter to exit'
    exit 1
} elseif ($build -lt $recommendedBuild) {
    Write-Host ''
    Write-Host "[!] Windows build $build is supported; $recommendedBuild (11 25H2) is recommended." -ForegroundColor Yellow
    Write-Host "    https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information" -ForegroundColor DarkGray
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    $shell    = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
    $shellCmd = Get-Command $shell -ErrorAction SilentlyContinue
    if (-not $shellCmd) { Write-Host "[!!] Shell '$shell' not found." -ForegroundColor Red; exit 1 }
    Start-Process -FilePath $shellCmd.Source `
                  -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`"" `
                  -Verb RunAs
    exit
}

# Relaunch in PS7 if elevation landed in PS5 (pattern from WinDeploy)
if (-not $isPwsh7) {
    $pwshExe = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
    if (-not (Test-Path $pwshExe)) {
        $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
        $pwshExe = if ($pwshCmd) { $pwshCmd.Source } else { $null }
    }
    if ($pwshExe) {
        Write-Host '[pcHealth] Relaunching in PowerShell 7...' -ForegroundColor Yellow
        Start-Process -FilePath $pwshExe `
                      -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`"" `
                      -Wait -NoNewWindow
        exit
    }
    # Fall through — pwsh not found yet; installer below will handle it.
}

# -- Dependency check ----------------------------------------------------------
Write-Host ''
Write-Host '[pcHealth] Checking dependencies...' -ForegroundColor Cyan

$pad = 24
function Write-DepStatus($label, $ok, [bool]$Optional = $false) {
    $dots = '.' * ($pad - $label.Length)
    if ($ok) {
        Write-Host "  $label $dots OK"            -ForegroundColor Green
    } elseif ($Optional) {
        Write-Host "  $label $dots not installed" -ForegroundColor Yellow
    } else {
        Write-Host "  $label $dots NOT FOUND"     -ForegroundColor Red
    }
}

$pwshOk = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)

$smartctlOk = (Test-Path (Join-Path $env:ProgramFiles 'smartmontools\bin\smartctl.exe')) -or
              [bool](Get-Command smartctl -ErrorAction SilentlyContinue)

Write-DepStatus 'PowerShell 7' $pwshOk
Write-DepStatus -label 'smartmontools' -ok $smartctlOk -Optional $true

# -- Install PowerShell 7 -----------------------------------------------------
if (-not $pwshOk) {
    Write-Host ''
    Write-Host '[pcHealth] PowerShell 7 is required to run this application.' -ForegroundColor Yellow

    $answer = Read-Host '           Install now via winget? [Y/N]'
    if ($answer -notmatch '^[Yy]') {
        Write-Host ''
        Write-Host '[!!] Cannot continue without PowerShell 7.' -ForegroundColor Red
        Read-Host 'Press Enter to exit'
        exit 1
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host '[!!] winget is not available. Install PowerShell 7 manually:' -ForegroundColor Red
        Write-Host '     https://aka.ms/powershell' -ForegroundColor Cyan
        Read-Host 'Press Enter to exit'
        exit 1
    }

    Write-Host ''
    Write-Host '[pcHealth] Installing PowerShell 7...' -ForegroundColor Cyan
    winget install --source winget --id Microsoft.PowerShell -e --silent `
        --accept-package-agreements --accept-source-agreements

    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path', 'User')

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Host '[!!] Installation completed but pwsh was not found. Please restart and try again.' -ForegroundColor Red
        Read-Host 'Press Enter to exit'
        exit 1
    }

    Write-Host '[OK] PowerShell 7 installed.' -ForegroundColor Green
}

# -- Optional: smartmontools --------------------------------------------------
if (-not $smartctlOk) {
    Write-Host ''
    Write-Host '[pcHealth] smartmontools is recommended for full SMART disk health data.' -ForegroundColor Yellow
    Write-Host '           Without it, life %, temperature and power-on hours are unavailable.' -ForegroundColor DarkGray

    $answer = Read-Host '           Install now via winget? [Y/N]'
    if ($answer -match '^[Yy]') {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --source winget --id smartmontools.smartmontools -e --silent `
                --accept-package-agreements --accept-source-agreements
            $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                        [System.Environment]::GetEnvironmentVariable('Path', 'User')
        } else {
            Write-Host '[!!] winget not available. Install from: https://www.smartmontools.org/' -ForegroundColor Yellow
        }

        if (Get-Command smartctl -ErrorAction SilentlyContinue) {
            Write-Host '[OK] smartmontools installed.' -ForegroundColor Green
        } else {
            Write-Host '[!!] Install may need a restart to take effect.' -ForegroundColor Yellow
        }
    } else {
        Write-Host '     Skipping — SMART data will be limited.' -ForegroundColor DarkGray
    }
}

# -- Launch app ----------------------------------------------------------------
Write-Host ''
Write-Host '[pcHealth] All dependencies satisfied. Starting pcHealth...' -ForegroundColor Green
Write-Host ''

$appScript = Join-Path $PSScriptRoot 'app.ps1'
& pwsh -NoProfile -ExecutionPolicy Bypass -File $appScript
