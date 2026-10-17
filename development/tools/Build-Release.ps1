#Requires -Version 7.0
# ============================================================================
# pcHealth — Release builder
# Publishes the GUI self-contained, packages GUI and CLI as ZIPs, and builds
# an MSI installer.
#
# Self-contained means the .NET runtime and the Windows App SDK travel with
# the app, so the TARGET MACHINE NEEDS NOTHING PRE-INSTALLED. That is the
# whole point: a technician's USB stick should work on a machine that is
# already broken, without first installing two runtimes on it.
#
# Build prerequisites on THIS machine:
#   - .NET 10 SDK            winget install Microsoft.DotNet.SDK.10
#   - WiX v7 (for the MSI)   dotnet tool install --global wix --version 7.0.0
#     v7 refuses to build until the Open Source Maintenance Fee EULA is
#     accepted; -acceptEula below does that. The fee is owed by organisations
#     above $10,000 annual revenue that use WiX to generate revenue, which
#     pcHealth is not. See https://docs.firegiant.com/wix/osmf/
#
# Usage:
#   pwsh -File development/tools/Build-Release.ps1
#   pwsh -File development/tools/Build-Release.ps1 -Architecture arm64
#   pwsh -File development/tools/Build-Release.ps1 -SingleFile
#   pwsh -File development/tools/Build-Release.ps1 -RequireMsi   # CI: fail if no MSI
# ============================================================================

[CmdletBinding()]
param(
    [ValidateSet('x64', 'arm64')]
    [string] $Architecture = 'x64',

    [string] $Output = (Join-Path $PSScriptRoot '..\..\dist'),

    # Packs the managed assemblies into pcHealth.exe. The Windows App SDK's
    # native binaries cannot all be merged, so this shrinks the file count
    # rather than producing a literal single file. Off by default because the
    # MSI is the one-file answer and this path is the less-travelled one.
    [switch] $SingleFile,

    # Turns a missing WiX toolset from a warning into an error. The release
    # workflow passes this so a release can never silently ship without its
    # installer.
    [switch] $RequireMsi
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$version  = (Get-Content (Join-Path $repoRoot 'VERSION')).Trim()
$rid      = "win-$Architecture"

$distDir    = $Output
$stageDir   = Join-Path $distDir '_stage'
$publishDir = Join-Path $distDir "_publish\$rid"
$cliStage   = Join-Path $stageDir "pcHealth-CLI-$version"
$guiStage   = Join-Path $stageDir "pcHealth-$version"

$guiZipPath = Join-Path $distDir "pcHealth-$version-$rid.zip"
$cliZipPath = Join-Path $distDir "pcHealth-CLI-$version.zip"
$msiPath    = Join-Path $distDir "pcHealth-$version-$rid.msi"

# ── Banner ────────────────────────────────────────────────────────────────────

Write-Host ''
Write-Host "[Build-Release] pcHealth v$version  |  $rid  |  self-contained" -ForegroundColor Cyan
Write-Host ''

# ── Clean ─────────────────────────────────────────────────────────────────────

Write-Host '[1/5] Cleaning dist/...' -ForegroundColor Yellow

if (Test-Path $distDir) { Remove-Item $distDir -Recurse -Force }
$null = New-Item $guiStage   -ItemType Directory -Force
$null = New-Item $cliStage   -ItemType Directory -Force
$null = New-Item $publishDir -ItemType Directory -Force

# ── Publish GUI ───────────────────────────────────────────────────────────────

Write-Host '[2/5] Publishing GUI (self-contained)...' -ForegroundColor Yellow

$csproj = Join-Path $repoRoot 'src\Windows\GUI\pcHealth\pcHealth.csproj'

# WindowsAppSDKSelfContained and WindowsPackageType live in the csproj; the
# .NET side is set here so an ordinary `dotnet build` during development stays
# fast and framework-dependent.
$publishArgs = @(
    'publish', $csproj
    '--configuration', 'Release'
    '--runtime', $rid
    '--self-contained', 'true'
    '--output', $publishDir
    '--nologo'
)
if ($SingleFile) {
    # IncludeNativeLibrariesForSelfExtract pulls what native binaries it can
    # into the exe; they are extracted to a temp directory on first launch.
    $publishArgs += @(
        '-p:PublishSingleFile=true'
        '-p:IncludeNativeLibrariesForSelfExtract=true'
    )
}
# Never trim: WinUI 3 resolves XAML types by reflection, and a trimmed build
# fails at runtime rather than at build time.
$publishArgs += '-p:PublishTrimmed=false'

dotnet @publishArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "dotnet publish failed (exit $LASTEXITCODE)."
}

if (-not (Test-Path (Join-Path $publishDir 'pcHealth.exe'))) {
    Write-Error "Publish succeeded but pcHealth.exe is missing from $publishDir."
}

Copy-Item "$publishDir\*" $guiStage -Recurse

# ── Package ZIPs ──────────────────────────────────────────────────────────────

Write-Host '[3/5] Packaging ZIPs...' -ForegroundColor Yellow

# GUI — folder-nested so WinGet NestedInstallerFiles can target the EXE
Compress-Archive -Path $guiStage -DestinationPath $guiZipPath -CompressionLevel Optimal

# CLI — copy PS1 scripts as-is
Copy-Item (Join-Path $repoRoot 'src\Windows\CLI\*') $cliStage -Recurse
Compress-Archive -Path $cliStage -DestinationPath $cliZipPath -CompressionLevel Optimal

# ── Build MSI ─────────────────────────────────────────────────────────────────

Write-Host '[4/5] Building MSI...' -ForegroundColor Yellow

$wix = Get-Command wix -CommandType Application -ErrorAction SilentlyContinue
if (-not $wix) {
    $message = 'WiX toolset not found. Install it with: dotnet tool install --global wix'
    if ($RequireMsi) { Write-Error $message }
    Write-Host "     [--] $message" -ForegroundColor Yellow
    Write-Host '     [--] Skipping the MSI; the ZIP above is complete on its own.' -ForegroundColor DarkGray
} else {
    $wxs = Join-Path $repoRoot 'installer\pcHealth.wxs'

    # -acceptEula names the EULA being accepted, not a bare switch: see the
    # note at the top of this file for who accepted it and why.
    & $wix.Source build $wxs `
        -acceptEula wix7 `
        -arch $Architecture `
        -d "Version=$version" `
        -d "PublishDir=$((Resolve-Path $publishDir).Path)" `
        -out $msiPath

    if ($LASTEXITCODE -ne 0) {
        Write-Error "wix build failed (exit $LASTEXITCODE)."
    }
}

# ── SHA256 hashes ─────────────────────────────────────────────────────────────

Write-Host '[5/5] Computing SHA256 hashes...' -ForegroundColor Yellow

$artifacts = @($guiZipPath, $cliZipPath) + @(if (Test-Path $msiPath) { $msiPath })

$hashes = $artifacts | ForEach-Object {
    [PSCustomObject]@{
        File   = Split-Path $_ -Leaf
        SHA256 = (Get-FileHash -Path $_ -Algorithm SHA256).Hash
    }
}

$hashes | ForEach-Object { "$($_.SHA256)  $($_.File)" } |
    Set-Content (Join-Path $distDir 'SHA256SUMS.txt')

# ── Cleanup staging dirs ──────────────────────────────────────────────────────

Remove-Item $stageDir -Recurse -Force
Remove-Item (Join-Path $distDir '_publish') -Recurse -Force

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ''
Write-Host '[OK] Artifacts written to:' -ForegroundColor Green
Write-Host "     $distDir" -ForegroundColor DarkGray
Write-Host ''

$hashes | ForEach-Object {
    Write-Host ("  {0}" -f $_.File) -ForegroundColor White
    Write-Host ("  SHA256: {0}" -f $_.SHA256) -ForegroundColor DarkGray
    Write-Host ''
}
