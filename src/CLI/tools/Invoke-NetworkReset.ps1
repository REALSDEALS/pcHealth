#Requires -Version 7.0
# ============================================================================
# pcHealth -- Reset Network Stack
# ============================================================================

Write-Host "`nResetting and flushing the network stack...`n" -ForegroundColor Cyan

Write-Host "[>>] Flushing DNS cache..." -ForegroundColor Yellow
Clear-DnsClientCache
Write-Host "[OK] DNS cache flushed." -ForegroundColor Green

Write-Host "[>>] Re-registering DNS..." -ForegroundColor Yellow
Register-DnsClient
Write-Host "[OK] DNS re-registered." -ForegroundColor Green

Write-Host "[>>] Releasing and renewing DHCP leases..." -ForegroundColor Yellow
Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration |
    Where-Object { $_.DHCPEnabled -and $_.IPEnabled } |
    ForEach-Object {
        Invoke-CimMethod -InputObject $_ -MethodName ReleaseDHCPLease | Out-Null
        Invoke-CimMethod -InputObject $_ -MethodName RenewDHCPLease  | Out-Null
    }
Write-Host "[OK] DHCP leases renewed." -ForegroundColor Green

# Winsock reset rebuilds the Windows Sockets catalog from scratch.
Write-Host "[>>] Resetting Winsock catalog..." -ForegroundColor Yellow
netsh winsock reset catalog | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Winsock reset failed (exit $LASTEXITCODE). Run as Administrator."
} else {
    Write-Host "[OK] Winsock reset." -ForegroundColor Green
}

Write-Host "[>>] Resetting IPv4/IPv6 stack..." -ForegroundColor Yellow
netsh int ipv4 reset | Out-Null
$v4Exit = $LASTEXITCODE
netsh int ipv6 reset | Out-Null
$v6Exit = $LASTEXITCODE
if ($v4Exit -ne 0 -or $v6Exit -ne 0) {
    Write-Warning "IP stack reset failed (IPv4 exit $v4Exit, IPv6 exit $v6Exit). Run as Administrator."
} else {
    Write-Host "[OK] IP stack reset." -ForegroundColor Green
}

Write-Host "`nNetwork stack reset complete. A reboot may be required.`n" -ForegroundColor Green
