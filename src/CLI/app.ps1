#Requires -Version 7.0
# ============================================================================
# pcHealth -- CLI
# Auto-detects platform (Windows/Linux) and loads menus.
# ============================================================================

$ErrorActionPreference = 'Stop'

# -- Platform detection + version guards ---------------------------------------
if ($IsLinux) {
    # Also checked in Start.ps1; repeated here as safety net for direct invocation.
    $kernelVersion = (uname -r)
    $kernelMajor   = [int]($kernelVersion -split '[\.\-]')[0]
    if ($kernelMajor -lt 7) {
        Write-Host "[!!] pcHealth cannot run on kernel $kernelVersion." -ForegroundColor Red
        Write-Host "     Minimum required: kernel 7.0." -ForegroundColor Red
        exit 1
    }
    # Also checked in Start.ps1; repeated here so tools can rely on being root
    # and call the package manager and systemctl directly, without sudo.
    $uid = "$(& id -u 2>$null)".Trim()
    if ($uid -ne '0') {
        Write-Host '[!!] pcHealth must be run as root on Linux.' -ForegroundColor Red
        Write-Host '     Run: sudo pwsh src/CLI/Start.ps1'       -ForegroundColor Yellow
        exit 1
    }
    $Global:PcPlatform      = 'Linux'
    $Global:PcPlatformLabel = 'Linux'
} elseif ($IsWindows) {
    # Also checked in Start.ps1 before elevation; repeated here as safety net.
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 26200) {
        Write-Host "[!!] pcHealth cannot run on Windows build $build." -ForegroundColor Red
        Write-Host "     Minimum required: build 26200 (Windows 11 version 25H2)." -ForegroundColor Red
        Write-Host "     Please upgrade your system." -ForegroundColor Yellow
        exit 1
    }
    $Global:PcPlatform      = 'Windows'
    $Global:PcPlatformLabel = 'Windows'
} else {
    Write-Host "[!!] Unsupported platform. pcHealth supports Windows and Linux only." -ForegroundColor Red
    exit 1
}

# Console resize -- Windows only. Terminal width/height on Linux is managed by
# the shell and cannot be set programmatically via RawUI on most hosts.
if (-not $IsLinux) {
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
}

# $Global:pcHealthRoot is used by menus to resolve the tools/ path.
# Set before dot-sourcing so menus can reference it at load time.
$Global:pcHealthRoot = $PSScriptRoot

$versionFile = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'VERSION'
$Global:PcVersion = if (Test-Path $versionFile) {
    (Get-Content $versionFile -Raw).Trim()
} else { 'unknown' }

# Order matters: Helpers must load before Main/Tools/Programs.
. (Join-Path -Path $PSScriptRoot -ChildPath 'menus' -AdditionalChildPath 'Helpers.ps1')

# Resolved once here: the Tools menu hides package- and boot-related tools on
# image-based systems, where they cannot work.
$Global:PcImageBased = Test-PcImageBasedSystem
. (Join-Path -Path $PSScriptRoot -ChildPath 'menus' -AdditionalChildPath 'Main.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'menus' -AdditionalChildPath 'Tools.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'menus' -AdditionalChildPath 'Programs.ps1')

Show-MainMenu
