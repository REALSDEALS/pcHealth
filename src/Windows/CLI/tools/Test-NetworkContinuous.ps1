#Requires -Version 7.0
# ============================================================================
# pcHealth -- Continuous Ping Test
# Press Ctrl+C to stop.
# ============================================================================

Write-Host "`nContinuous ping to 8.8.8.8  (Ctrl+C to stop)`n" -ForegroundColor Cyan

try {
    while ($true) {
        $r = Test-Connection -TargetName '8.8.8.8' -Count 1 -ErrorAction SilentlyContinue
        if ($r -and $r.Status -eq 'Success') {
            Write-Host "  Reply from $($r.DisplayAddress): time=$($r.Latency)ms" -ForegroundColor Green
        } else {
            Write-Host "  Request timed out." -ForegroundColor Red
        }
        Start-Sleep -Seconds 1
    }
} finally {
    Write-Host "`n  Ping test stopped.`n" -ForegroundColor DarkGray
}
