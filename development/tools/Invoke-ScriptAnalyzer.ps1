# ============================================================================
# pcHealth - Local PSScriptAnalyzer runner
# Uses the same settings file as the CI pipeline so results are identical.
#
# Usage:
#   pwsh -File development/tools/Invoke-ScriptAnalyzer.ps1
#   pwsh -File development/tools/Invoke-ScriptAnalyzer.ps1 -Path src/CLI
#   pwsh -File development/tools/Invoke-ScriptAnalyzer.ps1 -Severity Error
# ============================================================================

[CmdletBinding()]
param(
    # Directory or file to analyse. Defaults to src/.
    [string] $Path = (Join-Path $PSScriptRoot '..\..\src'),

    # Minimum severity to report. Information | Warning | Error
    [ValidateSet('Information', 'Warning', 'Error')]
    [string] $Severity = 'Warning'
)

# Re-launch under pwsh 7 when invoked from Windows PowerShell 5.
# Requires -Version 7.0 would throw at parse time and block this re-launch.
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

# ── Ensure PSScriptAnalyzer is available ──────────────────────────────────────
if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
    Write-Host '[setup] PSScriptAnalyzer not found. Installing...' -ForegroundColor Cyan
    Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
}
if (-not (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)) {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
}

# ── Same settings file the CI pipeline uses ───────────────────────────────────
$settingsFile = (Resolve-Path (Join-Path $PSScriptRoot '..\..' '.github' 'PSScriptAnalyzerSettings.psd1')).Path
$scanPath     = (Resolve-Path $Path).Path

Write-Host ''
Write-Host "[PSScriptAnalyzer] Scanning : $scanPath" -ForegroundColor Cyan
Write-Host "[PSScriptAnalyzer] Settings : $settingsFile" -ForegroundColor Cyan
Write-Host "[PSScriptAnalyzer] Severity : $Severity+" -ForegroundColor Cyan
Write-Host ''

# ── Run analysis ──────────────────────────────────────────────────────────────
$allResults = Invoke-ScriptAnalyzer -Path $scanPath -Recurse `
    -Settings $settingsFile -Severity $Severity, 'Error' |
    Sort-Object ScriptPath, Line

if (-not $allResults) {
    Write-Host '[OK] No issues found.' -ForegroundColor Green
    Write-Host ''
    exit 0
}

# ── Report grouped by file ────────────────────────────────────────────────────
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path.TrimEnd('\') + '\'

foreach ($group in ($allResults | Group-Object ScriptPath)) {
    $rel = $group.Name -replace [regex]::Escape($repoRoot), ''
    Write-Host "  $rel" -ForegroundColor White

    foreach ($issue in $group.Group) {
        $sev   = $issue.Severity.ToString()
        $color = if ($sev -eq 'Error') { 'Red' } elseif ($sev -eq 'Warning') { 'Yellow' } else { 'Gray' }
        $line  = if ($issue.Line) { $issue.Line.ToString().PadLeft(4) } else { '   -' }
        Write-Host ("    [{0,-7}] line {1}  {2}" -f $sev, $line, $issue.RuleName) -ForegroundColor $color
        Write-Host ("             {0}" -f $issue.Message) -ForegroundColor DarkGray
    }
    Write-Host ''
}

# ── Summary ───────────────────────────────────────────────────────────────────
$errors   = @($allResults | Where-Object { $_.Severity.ToString() -eq 'Error'   }).Count
$warnings = @($allResults | Where-Object { $_.Severity.ToString() -eq 'Warning' }).Count

Write-Host ('-' * 60)
Write-Host ("  Errors: {0}   Warnings: {1}   Total: {2}" -f $errors, $warnings, $allResults.Count)
Write-Host ''

exit $(if ($errors -gt 0) { 1 } else { 0 })
