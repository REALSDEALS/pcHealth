#Requires -Version 7.0
# ============================================================================
# pcHealth — BOM encoding fixer
# Ensures all .ps1 files under src/ are saved with UTF-8 BOM encoding,
# which is required by PSScriptAnalyzer (PSUseBOMForUnicodeEncodedFile).
#
# Usage:
#   pwsh -File development/tools/Invoke-BomFix.ps1
#   pwsh -File development/tools/Invoke-BomFix.ps1 -Path src/CLI
#   pwsh -File development/tools/Invoke-BomFix.ps1 -WhatIf
# ============================================================================

[CmdletBinding(SupportsShouldProcess)]
param(
    # Directory to scan. Defaults to src/
    [string] $Path = (Join-Path $PSScriptRoot '..\..\src')
)

$ErrorActionPreference = 'Stop'

$scanPath = (Resolve-Path $Path).Path
$utf8Bom  = New-Object System.Text.UTF8Encoding $true

Write-Host ''
Write-Host "[BomFix] Scanning : $scanPath" -ForegroundColor Cyan
Write-Host ''

$fixed  = 0
$skipped = 0

foreach ($file in Get-ChildItem -Path $scanPath -Recurse -Filter '*.ps1') {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)

    # Check if BOM (EF BB BF) is already present
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $skipped++
        continue
    }

    $content = [System.IO.File]::ReadAllText($file.FullName)
    $rel     = $file.FullName.Replace($scanPath, '').TrimStart('/\')

    if ($PSCmdlet.ShouldProcess($rel, 'Add UTF-8 BOM')) {
        [System.IO.File]::WriteAllText($file.FullName, $content, $utf8Bom)
        Write-Host "  [fixed]   $rel" -ForegroundColor Green
        $fixed++
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ('-' * 60)
Write-Host ("  Fixed: {0}   Skipped (already BOM): {1}   Total: {2}" -f $fixed, $skipped, ($fixed + $skipped))
Write-Host ''
