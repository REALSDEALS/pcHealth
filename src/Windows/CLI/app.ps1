#Requires -Version 7.0
# ============================================================================
# pcHealth -- Windows CLI
# Checks the Windows build and loads the menus.
# ============================================================================

$ErrorActionPreference = 'Stop'

# -- Platform guard + version check --------------------------------------------
if (-not $IsWindows) {
    Write-Host '[!!] This is the Windows CLI. On Linux, use src/Linux instead:' -ForegroundColor Red
    Write-Host '     python3 -m pchealth' -ForegroundColor Yellow
    exit 1
}

# Also checked in Start.ps1 before elevation; repeated here as safety net.
# Only the hard floor is enforced here -- the "recommended build" note lives
# in Start.ps1 so a normal launch does not print it twice.
$build = [System.Environment]::OSVersion.Version.Build
if ($build -lt 19045) {
    Write-Host "[!!] pcHealth cannot run on Windows build $build." -ForegroundColor Red
    Write-Host "     Minimum required: build 19045 (Windows 10 version 22H2)." -ForegroundColor Red
    Write-Host "     Please upgrade your system." -ForegroundColor Yellow
    exit 1
}

$Global:PcPlatform      = 'Windows'
$Global:PcPlatformLabel = 'Windows'

try {
    $ui        = $Host.UI.RawUI
    $buf       = $ui.BufferSize
    $buf.Width = 220
    $ui.BufferSize = $buf
    $win           = $ui.WindowSize
    $win.Width     = [Math]::Min(220, $ui.MaxPhysicalWindowSize.Width)
    $win.Height    = [Math]::Min(50,  $ui.MaxPhysicalWindowSize.Height)
    $ui.WindowSize = $win
} catch {
    Write-Verbose "Console resize skipped on non-interactive host: $_"
}

# $Global:pcHealthRoot is used by menus to resolve the tools/ path.
# Set before dot-sourcing so menus can reference it at load time.
$Global:pcHealthRoot = $PSScriptRoot

# src/Windows/CLI -> src/Windows -> src -> repo root
$versionFile = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', '..', 'VERSION'
$Global:PcVersion = if (Test-Path $versionFile) {
    (Get-Content $versionFile -Raw).Trim()
} else { 'unknown' }

# Order matters: Helpers must load before Main/Tools/Programs.
. (Join-Path -Path $PSScriptRoot -ChildPath 'menus' -AdditionalChildPath 'Helpers.ps1')

. (Join-Path -Path $PSScriptRoot -ChildPath 'menus' -AdditionalChildPath 'Main.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'menus' -AdditionalChildPath 'Tools.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'menus' -AdditionalChildPath 'Programs.ps1')

Show-MainMenu
