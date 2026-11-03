#Requires -Version 7.0
# ============================================================================
# pcHealth -- Continuous Ping Test
# Press Q, Esc or Ctrl+C to stop.
# ============================================================================

Write-Host "`nContinuous ping to 8.8.8.8  (Q, Esc or Ctrl+C to stop)`n" -ForegroundColor Cyan

# A real Ctrl+C stops the whole PowerShell pipeline, which ends pcHealth
# itself rather than this tool. Read it as a key press instead and stop the
# loop ourselves, so the user lands back in the menu.
$watchKeys = -not [Console]::IsInputRedirected
$previousCtrlC = [Console]::TreatControlCAsInput
if ($watchKeys) { [Console]::TreatControlCAsInput = $true }

function Test-PcStopKey {
    while ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -in 'Q', 'Escape') { return $true }
        if ($key.Key -eq 'C' -and ($key.Modifiers -band [ConsoleModifiers]::Control)) { return $true }
    }
    return $false
}

try {
    $stop = $false
    while (-not $stop) {
        $r = Test-Connection -TargetName '8.8.8.8' -Count 1 -ErrorAction SilentlyContinue
        if ($r -and $r.Status -eq 'Success') {
            Write-Host "  Reply from $($r.DisplayAddress): time=$($r.Latency)ms" -ForegroundColor Green
        } else {
            Write-Host "  Request timed out." -ForegroundColor Red
        }
        # Wait about a second between pings, watching for a stop key.
        for ($i = 0; $i -lt 10 -and -not $stop; $i++) {
            if ($watchKeys) { $stop = Test-PcStopKey }
            Start-Sleep -Milliseconds 100
        }
    }
} finally {
    if ($watchKeys) { [Console]::TreatControlCAsInput = $previousCtrlC }
    Write-Host "`n  Ping test stopped.`n" -ForegroundColor DarkGray
}
