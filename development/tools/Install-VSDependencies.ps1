#Requires -Version 7.0
# ============================================================================
# pcHealth — Visual Studio dependency installer
# Installs all required Visual Studio components from .vsconfig using the
# Visual Studio Installer. Auto-elevates to Administrator if needed.
#
# Usage:
#   pwsh -File development/tools/Install-VSDependencies.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$setupExe = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe'
$vsConfig  = Join-Path $PSScriptRoot '..\..' '.vsconfig' | Resolve-Path

if (-not (Test-Path $setupExe)) {
    Write-Error 'Visual Studio Installer not found. Install Visual Studio first.'
}

$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Not elevated — relaunching as Administrator...'
    Start-Process pwsh -Verb RunAs -ArgumentList "-NoExit -File `"$PSCommandPath`""
    exit
}

$installPath = & 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe' `
    -latest -property installationPath 2>$null

if (-not $installPath) {
    Write-Error 'No Visual Studio installation found via vswhere.'
}

Write-Host "Installing VS components from .vsconfig into: $installPath"

& $setupExe modify `
    --installPath $installPath `
    --config $vsConfig `
    --passive

if ($LASTEXITCODE -ne 0) {
    Write-Error "VS Installer exited with code $LASTEXITCODE."
}

Write-Host 'Done. Restart Visual Studio if it was open.'
