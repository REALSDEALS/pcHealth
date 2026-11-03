#Requires -Version 7.0
# ============================================================================
# pcHealth -- Scan + Repair (SFC + DISM combined)
# Runs all steps unattended. RestoreHealth requires internet or install media.
# ============================================================================

function Get-SfcStatus {
    param([int]$ExitCode)
    switch ($ExitCode) {
        0       { 'Completed -- no remaining issues' }
        2       { 'Issues found -- could not repair all' }
        default { "Error (exit code $ExitCode)" }
    }
}

function Get-DismStatus {
    param([int]$ExitCode, [string]$Output)
    if ($ExitCode -ne 0)                                                { return "Failed (exit code $ExitCode)" }
    if ($Output -match 'No component store corruption was detected')    { return 'Clean -- no corruption detected' }
    if ($Output -match 'restore operation completed successfully')       { return 'Restored successfully' }
    if ($Output -match 'component store is repairable')                 { return 'Corruption found -- repairable' }
    # The sentences above are English only. On a Windows in another language
    # nothing matches, so say the result is unknown rather than call it fine.
    return 'Unknown -- read the DISM output above'
}

function Invoke-Dism {
    param([string]$Operation)
    $dism = Join-Path $env:SystemRoot 'System32\Dism.exe'
    $raw  = [System.Collections.Generic.List[string]]::new()
    # Stream each line as it arrives: RestoreHealth can take half an hour and
    # buffering the output made it look hung.
    & $dism /Online /Cleanup-Image $Operation 2>&1 | ForEach-Object {
        $line = "$_"
        $raw.Add($line)
        if ($line -and
            $line -notmatch '^\s*\['            -and
            $line -notmatch '^Deployment Image' -and
            $line -notmatch '^Version:'         -and
            $line -notmatch '^Image Version:') {
            Write-Host $line
        }
    }
    $exitCode = $LASTEXITCODE

    return [PSCustomObject]@{ ExitCode = $exitCode; Text = ($raw -join ' ') }
}

function Get-ResultColor {
    param([string]$Status)
    switch -Wildcard ($Status) {
        'Clean*'                    { 'Green'  }
        'Issues found and repaired' { 'Green'  }
        'Restored*'                 { 'Green'  }
        'Corruption found*'         { 'Yellow' }
        'Unknown*'                  { 'Yellow' }
        'Completed*'                { 'Green'  }
        default                     { 'Red'    }
    }
}

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host "  Scan + Repair  (SFC + DISM)" -ForegroundColor Cyan
Write-Host "$('=' * 60)" -ForegroundColor Cyan
Write-Host "  Runs SFC, DISM CheckHealth, ScanHealth, RestoreHealth,"
Write-Host "  and a final SFC pass. RestoreHealth requires internet.`n"

Write-Host "[>>] Step 1/5 -- System File Checker (SFC)..." -ForegroundColor Yellow
$sfc1Status = Get-SfcStatus (Start-Process -FilePath "$env:SystemRoot\System32\sfc.exe" `
    -ArgumentList '/scannow' -Wait -NoNewWindow -PassThru).ExitCode
Write-Host "[OK] SFC done.`n" -ForegroundColor Green

Write-Host "[>>] Step 2/5 -- DISM CheckHealth..." -ForegroundColor Yellow
$r = Invoke-Dism '/CheckHealth'
$checkStatus = Get-DismStatus $r.ExitCode $r.Text
Write-Host "[OK] CheckHealth done.`n" -ForegroundColor Green

Write-Host "[>>] Step 3/5 -- DISM ScanHealth..." -ForegroundColor Yellow
$r = Invoke-Dism '/ScanHealth'
$scanStatus = Get-DismStatus $r.ExitCode $r.Text
Write-Host "[OK] ScanHealth done.`n" -ForegroundColor Green

Write-Host "[>>] Step 4/5 -- DISM RestoreHealth..." -ForegroundColor Yellow
$r = Invoke-Dism '/RestoreHealth'
$restoreStatus = Get-DismStatus $r.ExitCode $r.Text
Write-Host "[$(if ($r.ExitCode -eq 0) { 'OK' } else { '!!' })] RestoreHealth done: $restoreStatus`n" -ForegroundColor (Get-ResultColor $restoreStatus)

Write-Host "[>>] Step 5/5 -- Final SFC pass to verify repairs..." -ForegroundColor Yellow
$sfc2Status = Get-SfcStatus (Start-Process -FilePath "$env:SystemRoot\System32\sfc.exe" `
    -ArgumentList '/scannow' -Wait -NoNewWindow -PassThru).ExitCode
Write-Host "[OK] Final SFC done.`n" -ForegroundColor Green

Write-Host "$('=' * 60)" -ForegroundColor Cyan
Write-Host "  Results Summary" -ForegroundColor Cyan
Write-Host "$('=' * 60)" -ForegroundColor Cyan
Write-Host ""

$results = [ordered]@{
    'SFC (initial)'      = $sfc1Status
    'DISM CheckHealth'   = $checkStatus
    'DISM ScanHealth'    = $scanStatus
    'DISM RestoreHealth' = $restoreStatus
    'SFC (final)'        = $sfc2Status
}

foreach ($key in $results.Keys) {
    $val = $results[$key]
    Write-Host ("  {0,-22}: " -f $key) -NoNewline
    Write-Host $val -ForegroundColor (Get-ResultColor $val)
}

Write-Host ""
Write-Host "$('=' * 60)" -ForegroundColor Cyan
Write-Host "  Full log: $env:SystemRoot\Logs\CBS\CBS.log" -ForegroundColor DarkGray
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan
