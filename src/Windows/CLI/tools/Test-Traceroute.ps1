#Requires -Version 7.0
# ============================================================================
# pcHealth -- Traceroute to Google
# ============================================================================
param(
    [string]$Target = 'google.com'
)

Write-Host "`nTraceroute to $Target (max 30 hops)...`n" -ForegroundColor Cyan

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
