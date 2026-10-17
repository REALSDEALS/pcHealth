#Requires -Version 7.0
# ============================================================================
# pcHealth — GitHub label push
# Creates, updates, and optionally removes labels on the remote repository.
# Requires the gh CLI authenticated with at least repo scope.
#
# Usage:
#   pwsh -File development/tools/Push-Labels.ps1
#   pwsh -File development/tools/Push-Labels.ps1 -DeleteOrphans
#   pwsh -File development/tools/Push-Labels.ps1 -WhatIf
# ============================================================================

[CmdletBinding(SupportsShouldProcess)]
param(
    # Delete any label on GitHub that is NOT in the canonical list below.
    # Removes stale defaults (duplicate, wontfix, etc.) and retired labels.
    [switch] $DeleteOrphans
)

$ErrorActionPreference = 'Stop'

# ── Verify gh CLI is available ────────────────────────────────────────────────
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error 'gh CLI not found. Install from https://cli.github.com/'
}

# ── Detect repo from the origin remote (not upstream) ────────────────────────
$originUrl = git remote get-url origin 2>$null
if (-not $originUrl) {
    Write-Error 'No origin remote found. Run from inside the repo.'
}
if ($originUrl -match 'github\.com[:/](.+?)(?:\.git)?$') {
    $repo = $Matches[1]
} else {
    Write-Error "Could not parse GitHub repo from origin URL: $originUrl"
}

Write-Host ''
Write-Host "[Push-Labels] Repository : $repo" -ForegroundColor Cyan

# ── Canonical label definitions ───────────────────────────────────────────────
$labels = @(
    # ── Triage ────────────────────────────────────────────────────────────────
    @{ name = 'bug';           color = 'd73a4a'; description = 'Something is not working.' }
    @{ name = 'documentation'; color = '0075ca'; description = 'Requesting or tracking a documentation improvement.' }
    @{ name = 'enhancement';   color = 'a2eeef'; description = 'New feature or improvement.' }
    @{ name = 'question';      color = 'd876e3'; description = 'Further information is requested.' }

    # ── Conventional commit types ─────────────────────────────────────────────
    @{ name = 'type/feature';  color = '0075ca'; description = 'New feature or functionality.' }
    @{ name = 'type/fix';      color = 'd73a4a'; description = 'Bug fix.' }
    @{ name = 'type/docs';     color = '0075ca'; description = 'Documentation changes.' }
    @{ name = 'type/chore';    color = 'e4e669'; description = 'Maintenance, cleanup, configuration.' }
    @{ name = 'type/refactor'; color = 'fbca04'; description = 'Code restructuring without behavior change.' }
    @{ name = 'type/perf';     color = 'd4c5f9'; description = 'Performance improvement.' }
    @{ name = 'type/style';    color = 'bfd4f2'; description = 'Code style or formatting changes.' }
    @{ name = 'type/revert';   color = 'f9d0c4'; description = 'Reverts a previous commit.' }
    @{ name = 'type/test';     color = 'c2e0c6'; description = 'Test additions or changes.' }

    # ── CI / dependencies ─────────────────────────────────────────────────────
    @{ name = 'type/ci';    color = '006b75'; description = 'CI/CD workflow changes.' }
    @{ name = 'type/deps';  color = '0366d6'; description = 'Dependency or action version updates.' }
    @{ name = 'type/build'; color = 'fdb913'; description = 'Build system or tooling changes.' }
    @{ name = 'dotnet';     color = '512bd4'; description = 'NuGet / .NET SDK changes.' }
    @{ name = 'winui3';       color = '0078d4'; description = 'WinUI 3 / Windows App SDK changes.' }

    # ── Status ────────────────────────────────────────────────────────────────
    @{ name = 'security';        color = 'e11d48'; description = 'Security-related changes or vulnerabilities.' }
    @{ name = 'breaking-change'; color = 'b60205'; description = 'Introduces a breaking change.' }
    @{ name = 'pinned';          color = 'cfd3d7'; description = 'Pinned - never auto-closed by stale bot.' }
    @{ name = 'stale';           color = 'cfd3d7'; description = 'Auto-marked stale due to inactivity.' }

    # ── Platform ──────────────────────────────────────────────────────────────
    @{ name = 'windows-11'; color = '0078d4'; description = 'Windows 11 / GUI related.' }
    @{ name = 'linux';      color = 'f97316'; description = 'Linux CLI related.' }

    # ── Language ──────────────────────────────────────────────────────────────
    @{ name = 'powershell'; color = '5c3de4'; description = 'PowerShell script changes.' }
    @{ name = 'csharp';     color = '178600'; description = 'C# source code changes.' }
)

# ── Helper: run gh api and abort on failure ───────────────────────────────────
function Invoke-GhApi {
    param([string[]] $GhArgs)
    $out = gh api @GhArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "gh API error ($LASTEXITCODE): $out"
    }
    return $out
}

# ── Fetch all current labels from GitHub ─────────────────────────────────────
Write-Host '[Push-Labels] Fetching current labels...' -ForegroundColor Cyan
$existing = Invoke-GhApi "repos/$repo/labels", '--paginate' | ConvertFrom-Json

$canonicalNames = $labels | ForEach-Object { $_.name }
$created = 0
$updated = 0
$deleted = 0
$skipped = 0

# ── Upsert each canonical label ───────────────────────────────────────────────
Write-Host ''
foreach ($label in $labels) {
    $live    = $existing | Where-Object { $_.name -eq $label.name }
    $encoded = [uri]::EscapeDataString($label.name)

    if ($live) {
        if ($live.color -ne $label.color -or $live.description -ne $label.description) {
            if ($PSCmdlet.ShouldProcess($label.name, 'Update label')) {
                Invoke-GhApi "repos/$repo/labels/$encoded", '-X', 'PATCH',
                    '-f', "color=$($label.color)", '-f', "description=$($label.description)" | Out-Null
            }
            Write-Host "  [updated]  $($label.name)" -ForegroundColor Yellow
            $updated++
        } else {
            Write-Host "  [ok]       $($label.name)" -ForegroundColor DarkGray
            $skipped++
        }
    } else {
        if ($PSCmdlet.ShouldProcess($label.name, 'Create label')) {
            Invoke-GhApi "repos/$repo/labels", '-X', 'POST',
                '-f', "name=$($label.name)", '-f', "color=$($label.color)",
                '-f', "description=$($label.description)" | Out-Null
        }
        Write-Host "  [created]  $($label.name)" -ForegroundColor Green
        $created++
    }
}

# ── Delete orphaned labels ────────────────────────────────────────────────────
if ($DeleteOrphans) {
    Write-Host ''
    foreach ($live in $existing) {
        if ($live.name -notin $canonicalNames) {
            if ($PSCmdlet.ShouldProcess($live.name, 'Delete label')) {
                $encoded = [uri]::EscapeDataString($live.name)
                Invoke-GhApi "repos/$repo/labels/$encoded", '-X', 'DELETE' | Out-Null
            }
            Write-Host "  [deleted]  $($live.name)" -ForegroundColor Red
            $deleted++
        }
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host ('-' * 60)
Write-Host ("  Created: {0}   Updated: {1}   Deleted: {2}   OK: {3}" -f $created, $updated, $deleted, $skipped)
Write-Host ''
