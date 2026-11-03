#Requires -Version 7.0
# ============================================================================
# pcHealth -- Reset Network Stack
# ============================================================================

Write-Host "`nThis resets the network stack:" -ForegroundColor Cyan
Write-Host "  - The connection drops for a moment. Remote sessions (TeamViewer," -ForegroundColor Yellow
Write-Host "    AnyDesk, RDP) will disconnect." -ForegroundColor Yellow
Write-Host "  - Static IP and DNS settings can be lost; note them down first." -ForegroundColor Yellow
Write-Host "  - A reboot is needed afterwards.`n" -ForegroundColor Yellow
$confirm = (Read-Host "Reset the network stack? (y/n)").Trim().ToLower()
if ($confirm -ne 'y') {
    Write-Host "`nCancelled.`n" -ForegroundColor DarkGray
    return
}

Write-Host "`nResetting and flushing the network stack...`n" -ForegroundColor Cyan

# Each step reports its own result and the next one runs regardless: under
# the app's ErrorActionPreference = 'Stop' one failure would otherwise skip
# every step after it.
Write-Host "[>>] Flushing DNS cache..." -ForegroundColor Yellow
try {
    Clear-DnsClientCache -ErrorAction Stop
    Write-Host "[OK] DNS cache flushed." -ForegroundColor Green
} catch {
    Write-Warning "DNS cache flush failed: $_"
}

Write-Host "[>>] Re-registering DNS..." -ForegroundColor Yellow
try {
    Register-DnsClient -ErrorAction Stop
    Write-Host "[OK] DNS re-registered." -ForegroundColor Green
} catch {
    Write-Warning "DNS re-registration failed: $_"
}

Write-Host "[>>] Releasing and renewing DHCP leases..." -ForegroundColor Yellow
$adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue |
    Where-Object { $_.DHCPEnabled -and $_.IPEnabled }
$dhcpFailed = 0
foreach ($adapter in $adapters) {
    $release = Invoke-CimMethod -InputObject $adapter -MethodName ReleaseDHCPLease -ErrorAction SilentlyContinue
    $renew   = Invoke-CimMethod -InputObject $adapter -MethodName RenewDHCPLease   -ErrorAction SilentlyContinue
    if ($release.ReturnValue -ne 0 -or $renew.ReturnValue -ne 0) {
        $dhcpFailed++
        Write-Warning "DHCP on '$($adapter.Description)': release $($release.ReturnValue), renew $($renew.ReturnValue)."
    }
}
if ($dhcpFailed -eq 0) {
    Write-Host "[OK] DHCP leases renewed ($(@($adapters).Count) adapter(s))." -ForegroundColor Green
}

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
