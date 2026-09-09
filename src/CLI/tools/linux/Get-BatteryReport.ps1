#Requires -Version 7.0
# ============================================================================
# pcHealth -- Battery Report (Linux)
# Reads the kernel's power_supply class directly. No external tool needed:
# upower and acpi both read the same sysfs files.
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host '  Battery Report' -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

# Attribute names vary by driver and any of them may be absent.
function Get-SysAttribute {
    param([string]$Dir, [string[]]$Names)
    foreach ($name in $Names) {
        $path = Join-Path $Dir $name
        if (Test-Path $path) {
            $value = try { (Get-Content $path -Raw -ErrorAction Stop).Trim() } catch { $null }
            if ($value) { return $value }
        }
    }
    return $null
}

$supplyRoot = '/sys/class/power_supply'
if (-not (Test-Path $supplyRoot)) {
    Write-Host "[!!] $supplyRoot not found -- this kernel exposes no power supplies.`n" -ForegroundColor Red
    return
}

$batteries = @(Get-ChildItem $supplyRoot -ErrorAction SilentlyContinue |
    Where-Object { (Get-SysAttribute $_.FullName @('type')) -eq 'Battery' })

if (-not $batteries) {
    Write-Host "[!] No battery detected -- this looks like a desktop system.`n" -ForegroundColor Yellow
    return
}

foreach ($bat in $batteries) {
    $dir = $bat.FullName

    # Drivers report either energy (uWh) or charge (uAh); the health ratio holds
    # for both as long as full and design come from the same pair.
    $full       = Get-SysAttribute $dir @('energy_full', 'charge_full')
    $design     = Get-SysAttribute $dir @('energy_full_design', 'charge_full_design')
    $unit       = if (Test-Path (Join-Path $dir 'energy_full')) { 'Wh' } else { 'Ah' }
    $healthPct  = if ($full -and $design -and [double]$design -gt 0) {
        [Math]::Round(([double]$full / [double]$design) * 100, 1)
    } else { $null }

    $cycles  = Get-SysAttribute $dir @('cycle_count')
    $now     = Get-SysAttribute $dir @('energy_now', 'charge_now')
    $power   = Get-SysAttribute $dir @('power_now', 'current_now')
    $voltage = Get-SysAttribute $dir @('voltage_now')

    # sysfs reports micro-units throughout.
    $toUnit = { param($raw) if ($raw) { [Math]::Round([double]$raw / 1e6, 2) } else { 'N/A' } }

    [PSCustomObject]@{
        'Battery'        = $bat.Name
        'Manufacturer'   = (Get-SysAttribute $dir @('manufacturer'))  ?? 'N/A'
        'Model'          = (Get-SysAttribute $dir @('model_name'))    ?? 'N/A'
        'Technology'     = (Get-SysAttribute $dir @('technology'))    ?? 'N/A'
        'Status'         = (Get-SysAttribute $dir @('status'))        ?? 'N/A'
        'Charge'         = ((Get-SysAttribute $dir @('capacity'))     ?? 'N/A') + '%'
        "Full ($unit)"   = & $toUnit $full
        "Design ($unit)" = & $toUnit $design
        "Now ($unit)"    = & $toUnit $now
        'Voltage (V)'    = & $toUnit $voltage
        'Draw'           = if ($power) { "$(& $toUnit $power) $(if ($unit -eq 'Wh') { 'W' } else { 'A' })" } else { 'N/A' }
        'Cycle Count'    = $cycles ?? 'Not reported by driver'
        'Health'         = if ($null -ne $healthPct) { "$healthPct%" } else { 'N/A' }
    } | Format-List | Out-Host

    if ($null -ne $healthPct) {
        $verdict, $colour = switch ($healthPct) {
            { $_ -ge 80 } { 'Good -- the battery holds most of its design capacity.', 'Green';  break }
            { $_ -ge 60 } { 'Worn -- noticeably reduced runtime.',                    'Yellow'; break }
            default       { 'Poor -- consider replacing the battery.',                'Red' }
        }
        Write-Host "  $verdict" -ForegroundColor $colour
    }
    if (-not $cycles) {
        Write-Host '  [*] Many laptop batteries do not expose a cycle count to the kernel.' -ForegroundColor DarkGray
    }
    Write-Host ''
}
