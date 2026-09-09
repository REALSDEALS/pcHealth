#Requires -Version 7.0
# ============================================================================
# pcHealth -- Topgrade (Linux)
# Runs topgrade to update all managed software in one pass.
# topgrade is interactive (pacnew prompts, etc.) so it opens in a new terminal.
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host '  Topgrade -- Full System Upgrade' -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

if (-not (Get-Command topgrade -ErrorAction SilentlyContinue)) {
    Write-Host '[!!] topgrade is not installed.' -ForegroundColor Red
    Write-Host ''
    Write-Host '  Install it with your package manager:' -ForegroundColor DarkGray
    Write-Host '    Arch / CachyOS / Manjaro:  sudo pacman -S topgrade' -ForegroundColor DarkGray
    Write-Host '    Debian / Ubuntu / Fedora:  cargo install topgrade'  -ForegroundColor DarkGray
    Write-Host ''
    return
}

$user = Get-PcDesktopUser
if (-not $user) {
    Write-Host "[!!] Could not determine the desktop user.`n" -ForegroundColor Red
    return
}

Write-Host '  topgrade will upgrade:' -ForegroundColor DarkGray
Write-Host '    packages, flatpak, VS Code extensions, uv tools,' -ForegroundColor DarkGray
Write-Host '    gcloud, helm, firmware, and more.' -ForegroundColor DarkGray
Write-Host ''

# Reconstruct the session environment so GNOME Shell extensions and
# session-aware tools (gcloud, gdbus) work when topgrade is spawned from a sudo
# context that doesn't inherit the user's graphical session.
# Each value is a separate argv token for `env` rather than text spliced into a
# shell command, so a hostile DISPLAY cannot become an extra command.
$sessionEnv = @(
    "DBUS_SESSION_BUS_ADDRESS=$($user.Dbus)"
    "WAYLAND_DISPLAY=$($env:WAYLAND_DISPLAY ?? 'wayland-0')"
    "DISPLAY=$($env:DISPLAY ?? ':0')"
)
# Fixed literal -- the shell is only here to hold the window open afterwards.
$runCmd = @('sudo', '-u', $user.Name, 'env') + $sessionEnv +
          @('bash', '-c', 'topgrade; echo; read -r -p "Press Enter to close..."')

$terminals = [ordered]@{
    'gnome-terminal' = @('--wait', '--')
    'konsole'        = @('--hold', '-e')
    'alacritty'      = @('-e')
    'kitty'          = @()
    'xfce4-terminal' = @('--hold', '-e')
    'xterm'          = @('-hold', '-e')
}

foreach ($term in $terminals.Keys) {
    if (Get-Command $term -ErrorAction SilentlyContinue) {
        Write-Host "[>>] Opening topgrade in $term..." -ForegroundColor Yellow
        & $term @($terminals[$term] + $runCmd)
        return
    }
}

Write-Host '[!!] No supported terminal emulator found.' -ForegroundColor Red
Write-Host '  Install one of: gnome-terminal, konsole, alacritty, kitty, xterm' -ForegroundColor DarkGray
Write-Host ''
