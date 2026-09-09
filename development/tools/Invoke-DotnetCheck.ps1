# ============================================================================
# pcHealth — Local .NET format and build checker
# Mirrors the CI pipeline so issues are caught before pushing.
#
# Usage:
#   pwsh -File development/tools/Invoke-DotnetCheck.ps1              # format check (same as CI)
#   pwsh -File development/tools/Invoke-DotnetCheck.ps1 -Fix         # auto-fix formatting
#   pwsh -File development/tools/Invoke-DotnetCheck.ps1 -Build       # format check + build
#   pwsh -File development/tools/Invoke-DotnetCheck.ps1 -BuildOnly   # build only, skip format
# ============================================================================

[CmdletBinding()]
param(
    # Path to the .csproj. Defaults to the GUI project.
    [string] $Project = (Join-Path $PSScriptRoot '..\..\src\GUI\pcHealth\pcHealth.csproj'),

    # Auto-fix formatting instead of just checking.
    [switch] $Fix,

    # Also run dotnet build after the format check.
    [switch] $Build,

    # Skip format check, only build.
    [switch] $BuildOnly
)

# Re-launch under pwsh 7 when invoked from Windows PowerShell 5.
# #Requires -Version 7.0 would throw at parse time and block this re-launch.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) {
        Write-Error 'PowerShell 7 (pwsh) is required. Install from https://aka.ms/pscore6'
        return
    }
    & $pwsh.Source -File $PSCommandPath @PSBoundParameters
    return
}

$ErrorActionPreference = 'Stop'

# ── Preflight ────────────────────────────────────────────────────────────────
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host '[!!] dotnet SDK not found in PATH.' -ForegroundColor Red
    Write-Host '     Install from https://dot.net' -ForegroundColor DarkGray
    exit 1
}

$projectPath = (Resolve-Path $Project).Path
$sdkVersion  = (& dotnet --version 2>&1).Trim()

Write-Host ''
Write-Host "[dotnet] Project : $projectPath" -ForegroundColor Cyan
Write-Host "[dotnet] SDK     : $sdkVersion" -ForegroundColor Cyan
Write-Host ''

# ── Restore ──────────────────────────────────────────────────────────────────
Write-Host '[>>] Restoring NuGet packages...' -ForegroundColor Yellow
& dotnet restore $projectPath --verbosity quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host '[!!] Restore failed.' -ForegroundColor Red
    exit 1
}
Write-Host '[OK] Restore done.' -ForegroundColor Green
Write-Host ''

$exitCode = 0

# ── Format check / fix ───────────────────────────────────────────────────────
if (-not $BuildOnly) {
    if ($Fix) {
        Write-Host '[>>] Fixing formatting...' -ForegroundColor Yellow
        & dotnet format $projectPath --verbosity diagnostic
    } else {
        Write-Host '[>>] Checking formatting (same as CI)...' -ForegroundColor Yellow
        & dotnet format $projectPath --verify-no-changes --verbosity diagnostic
    }

    if ($LASTEXITCODE -ne 0) {
        if ($Fix) {
            Write-Host '[!!] dotnet format reported errors (see above).' -ForegroundColor Red
        } else {
            Write-Host '[!!] Formatting issues found. Run with -Fix to auto-correct.' -ForegroundColor Yellow
        }
        $exitCode = 1
    } else {
        if ($Fix) {
            Write-Host '[OK] Formatting fixed.' -ForegroundColor Green
        } else {
            Write-Host '[OK] Formatting clean.' -ForegroundColor Green
        }
    }
    Write-Host ''
}

# ── Build ────────────────────────────────────────────────────────────────────
if ($Build -or $BuildOnly) {
    Write-Host '[>>] Building...' -ForegroundColor Yellow
    & dotnet build $projectPath --no-restore --verbosity minimal
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[!!] Build failed.' -ForegroundColor Red
        $exitCode = 1
    } else {
        Write-Host '[OK] Build passed.' -ForegroundColor Green
    }
    Write-Host ''
}

exit $exitCode
