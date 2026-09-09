#Requires -Version 5.1
# ============================================================================
# pcHealth -- GUI Launcher (Windows)
# Checks dependencies, elevates to admin, builds and launches the WinUI 3 app.
# Stays PS 5.1-compatible so it can bootstrap dependencies on fresh systems.
# ============================================================================

$ErrorActionPreference = 'Stop'

# -- 0. Windows only -----------------------------------------------------------
# $IsLinux / $IsMacOS are PS6+ variables; on PS 5.1 they are $null (falsy).
if ($IsLinux -or $IsMacOS) {
    Write-Host '[!!] The pcHealth GUI is not available on Linux or macOS.' -ForegroundColor Red
    Write-Host '     Use src/CLI/start.sh to run the CLI version.'         -ForegroundColor Yellow
    exit 1
}

# Recommended and hard minimum Windows build versions (see README.md)
$recommendedBuild = 26200   # 25H2+
$hardMinimumBuild = 19045   # 22H2 (hard minimum)
$build = [System.Environment]::OSVersion.Version.Build

if ($build -lt $hardMinimumBuild) {
    Write-Host "[!!] pcHealth requires at least Windows build $hardMinimumBuild (22H2)." -ForegroundColor Red
    Write-Host "     Your build: $build" -ForegroundColor Red
    Write-Host "     Update Windows and try again." -ForegroundColor Yellow
    Read-Host 'Press Enter to exit'
    exit 1
} elseif ($build -lt $recommendedBuild) {
    Write-Host "[!] Recommended Windows build is $recommendedBuild (25H2+)." -ForegroundColor Yellow
    Write-Host "    Your build: $build" -ForegroundColor Yellow
    Write-Host "    pcHealth will continue but some features may be limited." -ForegroundColor DarkGray
}

# -- 1. Elevate ----------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    $shellName = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
    $shellPath = (Get-Command $shellName -ErrorAction Stop).Source
    Start-Process -FilePath $shellPath -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# -- 2. Dependency check and install -------------------------------------------
Write-Host ''
Write-Host '[pcHealth] Checking dependencies...' -ForegroundColor Cyan

# Checks one dependency. Installs automatically via winget if missing.
# Exits with an error if the dependency cannot be satisfied.
function Assert-Dep {
    param($Label, $WingetId, $ManualUrl, [scriptblock]$IsInstalled)

    $dots = '.' * [Math]::Max(2, 22 - $Label.Length)

    if (& $IsInstalled) {
        Write-Host "  $Label $dots OK" -ForegroundColor Green
        return
    }

    Write-Host "  $Label $dots NOT FOUND" -ForegroundColor Red
    Write-Host ''

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "[!!] winget is not available. Install $Label manually:" -ForegroundColor Red
        Write-Host "     $ManualUrl" -ForegroundColor Cyan
        Read-Host 'Press Enter to exit'
        exit 1
    }

    Write-Host "[pcHealth] Installing $Label..." -ForegroundColor Cyan
    winget install --source winget --id $WingetId -e --silent `
        --accept-package-agreements --accept-source-agreements

    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path', 'User')

    if (-not (& $IsInstalled)) {
        Write-Host "[!!] $Label installed but not detected. Please restart and re-run Start.ps1." -ForegroundColor Red
        Read-Host 'Press Enter to exit'
        exit 1
    }

    Write-Host "[OK] $Label installed." -ForegroundColor Green
    Write-Host ''
}

Assert-Dep 'PowerShell 7'     'Microsoft.PowerShell'        'https://aka.ms/powershell' `
    { [bool](Get-Command pwsh -ErrorAction SilentlyContinue) }

Assert-Dep '.NET 10 SDK'      'Microsoft.DotNet.SDK.10'     'https://dotnet.microsoft.com/download/dotnet/10.0' `
    { (Get-Command dotnet -ErrorAction SilentlyContinue) -and ((dotnet --list-sdks 2>$null) -match '^10\.') }

Assert-Dep 'Windows Terminal' 'Microsoft.WindowsTerminal'   'https://aka.ms/terminal' `
    { [bool](Get-Command wt -ErrorAction SilentlyContinue) }

Assert-Dep 'smartmontools'    'smartmontools.smartmontools' 'https://www.smartmontools.org/wiki/Download' `
    { (Test-Path (Join-Path $env:ProgramFiles 'smartmontools\bin\smartctl.exe')) -or
      [bool](Get-Command smartctl -ErrorAction SilentlyContinue) }

# -- 4. Detect architecture and derive output EXE path from csproj ------------
$projectFile = Join-Path $PSScriptRoot 'pcHealth\pcHealth.csproj'

# Detect the native architecture; default to win-x64 for everything else.
$rid = if ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq
           [System.Runtime.InteropServices.Architecture]::Arm64) { 'win-arm64' } else { 'win-x64' }

# Read TargetFramework from the csproj so this path never drifts from the project.
$tfm     = ([xml](Get-Content $projectFile)).Project.PropertyGroup.TargetFramework |
               Where-Object { $_ } | Select-Object -First 1
$exePath = Join-Path $PSScriptRoot "pcHealth\bin\Release\$tfm\$rid\pcHealth.exe"

# -- 5. Build ------------------------------------------------------------------
Write-Host ''
Write-Host "[pcHealth] All dependencies satisfied. Building pcHealth ($rid)..." -ForegroundColor Green
Write-Host ''

dotnet build $projectFile -c Release -r $rid --nologo -v minimal

if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host '[!!] Build failed. See output above for details.' -ForegroundColor Red
    Read-Host 'Press Enter to exit'
    exit 1
}

# -- 6. Launch -----------------------------------------------------------------
Write-Host ''
Write-Host '[pcHealth] Build succeeded. Launching pcHealth...' -ForegroundColor Green
Start-Process -FilePath $exePath
