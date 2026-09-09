#Requires -Version 7.0
# ============================================================================
# pcHealth -- Traceroute to Google
# ============================================================================
param(
    [string]$Target = 'google.com'
)

Write-Host "`nTraceroute to $Target (max 30 hops)...`n" -ForegroundColor Cyan

if ($IsLinux) {
    # Test-NetConnection -TraceRoute is not available on Linux.
    # Prefer traceroute; fall back to tracepath if not installed.
    $cmd = if (Get-Command traceroute -ErrorAction SilentlyContinue) { 'traceroute' }
           elseif (Get-Command tracepath -ErrorAction SilentlyContinue) { 'tracepath' }
           else { $null }

    if ($cmd) {
        & $cmd $Target
    } else {
        Write-Host "  Neither traceroute nor tracepath found." -ForegroundColor Yellow
        Write-Host "  Install via: sudo apt-get install traceroute  (or dnf/pacman)`n" -ForegroundColor DarkGray
    }
} else {
    $result = Test-NetConnection -ComputerName $Target -TraceRoute -ErrorAction SilentlyContinue

    if ($result) {
        $hop = 1
        foreach ($node in $result.TraceRoute) {
            Write-Host ("  {0,2}  {1}" -f $hop, $node)
            $hop++
        }
        Write-Host "`n  Destination: $($result.RemoteAddress)  --  TCP: $($result.TcpTestSucceeded)`n" -ForegroundColor Cyan
    } else {
        Write-Host "  Traceroute failed. Check your network connection.`n" -ForegroundColor Red
    }
}
