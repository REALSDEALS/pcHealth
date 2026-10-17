#Requires -Version 7.0
# ============================================================================
# pcHealth -- Windows License Key
# Attempts OA3 (UEFI/BIOS firmware) and DigitalProductId (registry decode).
# ============================================================================

$genericKeys = @{
    'VK7JG-NPHTM-C97JM-9MPGT-3V66T' = 'Windows 11 Pro'
    'YTMG3-N6DKC-DKB77-7M9GH-8HVX7' = 'Windows 11 Pro N'
    'YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY' = 'Windows 11 Home'
    'TX9XD-98N7V-6WMQ6-BX7FG-H8Q99' = 'Windows 11 Home N'
    'NPPR9-FWDCX-D2C8J-H872K-2YT43' = 'Windows 11 Enterprise'
    'NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J' = 'Windows 11 Pro for Workstations'
    'W269N-WFGWX-YVC9B-4J6C9-T83GX' = 'Windows 10/11 Pro'
}

function Get-KeyFromOA3 {
    try {
        $key = (Get-CimInstance -Query 'SELECT * FROM SoftwareLicensingService').OA3xOriginalProductKey
        return $key
    } catch {
        # OA3 key is absent on most non-OEM machines; log for diagnostics only.
        Write-Verbose "Get-KeyFromOA3: CIM query failed: $_"
        return $null
    }
}

function Get-KeyFromDigitalProductId {
    # The key is encoded in bytes 52-66 of the DigitalProductId blob using a custom
    # Base24 charset (BCDFGHJKMPQRTVWXY2346789) that excludes vowels and ambiguous chars.
    try {
        $dpid = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DigitalProductId
        if (-not $dpid) { return $null }

        $key    = $dpid[52..66]
        $chars  = 'BCDFGHJKMPQRTVWXY2346789'
        $productKey = ''

        $isWin8Plus = ($key[14] -shr 3) -band 1
        # Clear bit 3 before base-24 decode. The original code also had
        # `-bor (($isWin8Plus -band 2) -shl 2)`, but $isWin8Plus is always 0 or 1
        # (result of -band 1), so ($isWin8Plus -band 2) is always 0, making that
        # OR operand a no-op. The simplified form is therefore equivalent.
        $key[14]    = $key[14] -band 0xF7

        for ($i = 24; $i -ge 0; $i--) {
            $cur = 0
            for ($j = 14; $j -ge 0; $j--) {
                $cur     = ($cur -shl 8) -bor $key[$j]
                $key[$j] = [math]::Floor($cur / 24)
                $cur     = $cur % 24
            }
            $productKey = $chars[$cur] + $productKey
        }

        if ($isWin8Plus) {
            $firstChar = $productKey[0]
            $nIndex = 0
            for ($i = 0; $i -lt $chars.Length; $i++) {
                if ($chars[$i] -eq $firstChar) { $nIndex = $i; break }
            }
            $productKey = $productKey.Substring(1).Insert($nIndex, 'N')
        }

        $formatted = ''
        for ($i = 0; $i -lt 25; $i++) {
            $formatted += $productKey[$i]
            if (($i + 1) % 5 -eq 0 -and $i -lt 24) { $formatted += '-' }
        }
        return $formatted
    } catch {
        # Registry read or blob decoding failed; log for diagnostics only.
        Write-Verbose "Get-KeyFromDigitalProductId: failed: $_"
        return $null
    }
}

function Test-KeyFormat {
    param([string]$Key)
    return $Key -match '^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$'
}

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host "  Windows License Key" -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

$os = Get-CimInstance -ClassName Win32_OperatingSystem
Write-Host "  Detected: $($os.Caption) (Build $($os.BuildNumber))`n" -ForegroundColor Yellow

Write-Host "  [>>] Method 1: OA3 (UEFI/BIOS firmware)..." -ForegroundColor DarkGray
$oa3Key = Get-KeyFromOA3
$oa3OK  = $oa3Key -and (Test-KeyFormat $oa3Key)
Write-Host "       $(if ($oa3OK) { '[+] Found' } else { '[-] Not found' })$(if ($oa3OK) { ": $oa3Key" } else { '' })" -ForegroundColor $(if ($oa3OK) { 'Green' } else { 'DarkGray' })

Write-Host "  [>>] Method 2: DigitalProductId (registry decode)..." -ForegroundColor DarkGray
$regKey = Get-KeyFromDigitalProductId
$regOK  = $regKey -and (Test-KeyFormat $regKey)
Write-Host "       $(if ($regOK) { '[+] Found' } else { '[-] Not found' })$(if ($regOK) { ": $regKey" } else { '' })" -ForegroundColor $(if ($regOK) { 'Green' } else { 'DarkGray' })

$bestKey    = if ($regOK) { $regKey } elseif ($oa3OK) { $oa3Key } else { $null }
$bestSource = if ($regOK) { 'Registry (DigitalProductId)' } elseif ($oa3OK) { 'UEFI/BIOS (OA3)' } else { 'None' }

Write-Host ''
if ($bestKey) {
    $isGeneric = $genericKeys.ContainsKey($bestKey)
    Read-Host "  Press Enter to reveal the license key"
    Write-Host ''
    Write-Host "  Primary Key  : $bestKey" -ForegroundColor $(if ($isGeneric) { 'Yellow' } else { 'Green' })
    Write-Host "  Source       : $bestSource"
    if ($isGeneric) {
        Write-Host "`n  [!] WARNING: This is a generic placeholder key ($($genericKeys[$bestKey]))." -ForegroundColor Yellow
        Write-Host "      It will not activate Windows. Your system may use a digital license" -ForegroundColor Yellow
        Write-Host "      linked to your Microsoft account, or was activated via KMS/MAK.`n"    -ForegroundColor Yellow
    } else {
        Write-Host "`n  Save this key in a secure location for future re-activation.`n" -ForegroundColor DarkGray
    }
} else {
    Write-Host "  No product key found.`n" -ForegroundColor Red
    Write-Host "  Your system may use a digital license linked to your Microsoft account,`n  or volume licensing (KMS/MAK).`n" -ForegroundColor DarkGray
}
