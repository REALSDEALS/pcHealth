#Requires -Version 7.0
# ============================================================================
# pcHealth -- Restart Audio (Linux)
# Detects PipeWire or PulseAudio and restarts the relevant user services.
# The audio server lives in the user's session, not root's, so every call is
# dropped to the desktop user with their session bus forwarded.
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host '  Restart Audio' -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

$user = Get-PcDesktopUser
if (-not $user) {
    Write-Host "[!!] Could not determine the desktop user.`n" -ForegroundColor Red
    return
}

# systemctl and its arguments are passed as individual tokens -- no shell involved.
function Invoke-UserCommand {
    param([string[]]$CommandLine)
    return & sudo -u $user.Name env "DBUS_SESSION_BUS_ADDRESS=$($user.Dbus)" @CommandLine 2>&1
}

function Restart-UserUnit {
    param([string]$Unit)
    Write-Host "[>>] Restarting $Unit..." -ForegroundColor Yellow
    $out = Invoke-UserCommand @('systemctl', '--user', 'restart', $Unit)
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Done.`n" -ForegroundColor Green
    } else {
        Write-Host "[!!] Exit code $LASTEXITCODE.`n" -ForegroundColor Red
        if ($out) { Write-Host "  $out" -ForegroundColor DarkGray }
    }
}

# Exact match: `is-active` answers "inactive" too, which -match 'active' would accept.
$pipeWireState = "$(Invoke-UserCommand @('systemctl', '--user', 'is-active', 'pipewire'))".Trim()
$isPipeWire = $pipeWireState -eq 'active'
$hasPulse   = [bool](Get-Command pulseaudio -ErrorAction SilentlyContinue)

if ($isPipeWire) {
    Write-Host "  Detected: PipeWire`n" -ForegroundColor DarkGray
    'pipewire', 'pipewire-pulse', 'wireplumber' | ForEach-Object { Restart-UserUnit $_ }
} elseif ($hasPulse) {
    Write-Host "  Detected: PulseAudio`n" -ForegroundColor DarkGray
    Write-Host '[>>] Restarting PulseAudio...' -ForegroundColor Yellow
    # Kill then start as two invocations to avoid a shell compound command.
    Invoke-UserCommand @('pulseaudio', '--kill') | Out-Null
    Start-Sleep -Milliseconds 500
    $out = Invoke-UserCommand @('pulseaudio', '--start')
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Done.`n" -ForegroundColor Green
    } else {
        Write-Host "[!!] Exit code $LASTEXITCODE.`n" -ForegroundColor Red
        if ($out) { Write-Host "  $out" -ForegroundColor DarkGray }
    }
} else {
    Write-Host "[!!] No supported audio server found (PipeWire or PulseAudio).`n" -ForegroundColor Red
    return
}

Write-Host "  Audio services restarted.`n" -ForegroundColor Green
