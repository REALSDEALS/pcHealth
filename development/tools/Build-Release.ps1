#Requires -Version 7.0
# ============================================================================
# pcHealth — Release builder
# Builds the GUI (framework-dependent, no MSIX) and packages both GUI and
# CLI into distributable ZIP archives, ready for a GitHub Release or a
# WinGet manifest submission.
#
# Prerequisites on the TARGET machine:
#   - Windows App SDK 1.8 runtime
#     winget install Microsoft.WindowsAppRuntime.1.8
#   - .NET 10 Desktop Runtime
#     winget install Microsoft.DotNet.DesktopRuntime.10
#
# Usage:
#   pwsh -File development/tools/Build-Release.ps1
#   pwsh -File development/tools/Build-Release.ps1 -Architecture arm64
#   pwsh -File development/tools/Build-Release.ps1 -Output C:\my\dist
# ============================================================================

[CmdletBinding()]
param(
    [ValidateSet('x64', 'arm64')]
    [string] $Architecture = 'x64',

    [string] $Output = (Join-Path $PSScriptRoot '..\..\dist')
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$version  = (Get-Content (Join-Path $repoRoot 'VERSION')).Trim()
$rid      = "win-$Architecture"

$distDir    = $Output
$stageDir   = Join-Path $distDir '_stage'
$guiStage   = Join-Path $stageDir "pcHealth-$version"
$cliStage   = Join-Path $stageDir "pcHealth-CLI-$version"

$guiZipPath = Join-Path $distDir "pcHealth-$version-$rid.zip"
$cliZipPath = Join-Path $distDir "pcHealth-CLI-$version.zip"

# ── Banner ────────────────────────────────────────────────────────────────────

Write-Host ''
Write-Host "[Build-Release] pcHealth v$version  |  $rid" -ForegroundColor Cyan
Write-Host ''

# ── Clean ─────────────────────────────────────────────────────────────────────

Write-Host '[1/4] Cleaning dist/...' -ForegroundColor Yellow

if (Test-Path $distDir) { Remove-Item $distDir -Recurse -Force }
$null = New-Item $guiStage -ItemType Directory -Force
$null = New-Item $cliStage -ItemType Directory -Force

# ── Build GUI ─────────────────────────────────────────────────────────────────

Write-Host '[2/4] Building GUI...' -ForegroundColor Yellow

$csproj = Join-Path $repoRoot 'src\GUI\pcHealth\pcHealth.csproj'

dotnet build $csproj --configuration Release --runtime $rid --no-self-contained --nologo

if ($LASTEXITCODE -ne 0) {
    Write-Error "dotnet build failed (exit $LASTEXITCODE)."
}

# Read TargetFramework from csproj so the bin path never drifts.
$tfm      = ([xml](Get-Content $csproj)).Project.PropertyGroup.TargetFramework |
                Where-Object { $_ } | Select-Object -First 1
$binOut   = Join-Path $repoRoot "src\GUI\pcHealth\bin\Release\$tfm\$rid"

Copy-Item "$binOut\*" $guiStage -Recurse

# ── Package ZIPs ──────────────────────────────────────────────────────────────

Write-Host '[3/4] Packaging ZIPs...' -ForegroundColor Yellow

# GUI — folder-nested so WinGet NestedInstallerFiles can target the EXE
Compress-Archive -Path $guiStage -DestinationPath $guiZipPath -CompressionLevel Optimal

# CLI — copy PS1 scripts as-is
Copy-Item (Join-Path $repoRoot 'src\CLI\*') $cliStage -Recurse
Compress-Archive -Path $cliStage -DestinationPath $cliZipPath -CompressionLevel Optimal

# ── SHA256 hashes ─────────────────────────────────────────────────────────────

Write-Host '[4/4] Computing SHA256 hashes...' -ForegroundColor Yellow

$artifacts = @($guiZipPath, $cliZipPath)

$hashes = $artifacts | ForEach-Object {
    [PSCustomObject]@{
        File   = Split-Path $_ -Leaf
        SHA256 = (Get-FileHash -Path $_ -Algorithm SHA256).Hash
    }
}

$hashes | ForEach-Object { "$($_.SHA256)  $($_.File)" } |
    Set-Content (Join-Path $distDir 'SHA256SUMS.txt')

# ── Cleanup staging dir ───────────────────────────────────────────────────────

Remove-Item $stageDir -Recurse -Force

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
