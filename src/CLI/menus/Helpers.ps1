# ============================================================================
# pcHealth -- Shared -- UI Helpers
# Display and navigation utilities used by all menu scripts.
# ============================================================================

# Runs a native command and returns its trimmed output, or $null when the
# command is missing, fails, or prints nothing.
# The bare `(& cmd ...).Trim()` idiom throws on $null and aborts the whole tool.
# On Linux that is the common case, not the edge case: containers and WSL have
# no systemd (timedatectl, systemctl), and mokutil, lspci or uptime may not be
# installed at all.
function Get-PcCommandOutput {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Command,
        [Parameter(Position = 1)][string[]]$Arguments = @()
    )
    if (-not (Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue)) { return $null }
    $out = try { & $Command @Arguments 2>$null } catch { $null }
    if (-not $out) { return $null }
    $text = ($out -join "`n").Trim()
    if ($text) { return $text } else { return $null }
}

# Resolves the human user behind the session. Under `sudo pwsh` the process
# environment describes root, so tools that touch the desktop session -- audio,
# topgrade, the thumbnail cache, log off -- must not use $env:USER or $env:HOME.
# Returns $null on Windows and when no user can be determined.
function Get-PcDesktopUser {
    if (-not $IsLinux) { return $null }

    $name = $env:SUDO_USER
    if (-not $name) { $name = $env:USER }
    # sudo -i clears both; ask the kernel who owns the login session instead.
    if (-not $name) { $name = Get-PcCommandOutput 'id' @('-un') }
    if (-not $name) { return $null }

    $uid = Get-PcCommandOutput 'id' @('-u', $name)
    # Field 6 of the passwd entry is the home directory.
    $passwd  = Get-PcCommandOutput 'getent' @('passwd', $name)
    $homeDir = if ($passwd) { ($passwd -split ':')[5] } else { $null }
    if (-not $homeDir) { $homeDir = if ($name -eq 'root') { '/root' } else { "/home/$name" } }

    # Session bus of the user's login session; needed by `systemctl --user`.
    # The inherited address is passed on to `env` as key=value, so reject anything
    # that is not a D-Bus transport and derive the standard path instead.
    $dbus = $env:DBUS_SESSION_BUS_ADDRESS
    if ($dbus -notmatch '^(unix|tcp|nonce-tcp|autolaunch):') { $dbus = "unix:path=/run/user/$uid/bus" }

    [PSCustomObject]@{
        Name = $name
        Uid  = $uid
        Home = $homeDir
        Dbus = $dbus
    }
}

# True on image-based systems: Fedora Silverblue/Bazzite/Kinoite, openSUSE
# MicroOS and friends. /usr is read-only and the bootloader belongs to the
# deployment, so tools that manage packages or boot files are hidden there
# rather than taught a second dialect that would need chasing as bootc evolves.
function Test-PcImageBasedSystem {
    if (-not $IsLinux) { return $false }
    return (Test-Path '/run/ostree-booted') -or (Test-Path '/ostree')
}

# Detects the distro's package manager and the verbs pcHealth needs from it.
# Returns $null when the distro has no manager pcHealth knows.
# Refresh is $null where the update verb already syncs the package index.
# Verify names its own command: rpm and debsums do the checking, not the manager.
#
# Chosen by distro family, NOT by which binary happens to be on PATH. A
# Distrobox export or Homebrew readily puts apt and pacman on a Fedora box, and
# picking the first one found would run Debian commands against an rpm system.
function Get-PcPackageManager {
    $definitions = @{
        'apt'    = @{ Refresh = @('update');  List = @('list', '--upgradable'); Update = @('upgrade', '-y');  Install = @('install', '-y');      Verify = @('debsums', '-s')  }
        'dnf'    = @{ Refresh = $null;        List = @('check-update');         Update = @('upgrade', '-y');  Install = @('install', '-y');      Verify = @('rpm', '-Va')     }
        'pacman' = @{ Refresh = @('-Sy');     List = @('-Qu');                  Update = @('-Syu', '--noconfirm'); Install = @('-S', '--noconfirm'); Verify = @('pacman', '-Qkk') }
        'zypper' = @{ Refresh = @('refresh'); List = @('list-updates');         Update = @('update', '-y');   Install = @('install', '-y');      Verify = @('rpm', '-Va')     }
    }

    $info   = Get-LinuxDistroInfo
    $family = "$($info['ID']) $($info['ID_LIKE'])"

    $name = switch -Regex ($family) {
        'debian|ubuntu|mint|pop|elementary|zorin|kali' { 'apt';    break }
        'fedora|rhel|centos|almalinux|rocky'           { 'dnf';    break }
        'arch|cachyos|manjaro|endeavouros|artix'       { 'pacman'; break }
        'suse|sles'                                    { 'zypper'; break }
        default                                        { $null }
    }

    # Unrecognised distro: fall back to whatever is actually installed.
    if (-not $name) {
        $name = $definitions.Keys | Sort-Object |
            Where-Object { Get-Command $_ -CommandType Application -ErrorAction SilentlyContinue } |
            Select-Object -First 1
    }
    if (-not $name -or -not (Get-Command $name -CommandType Application -ErrorAction SilentlyContinue)) {
        return $null
    }
    return [PSCustomObject]($definitions[$name] + @{ Cmd = $name })
}

# Opens a URL in the user's browser.
# Start-Process cannot launch a URL on Linux -- it tries to exec it as a file --
# so hand the address to xdg-open, and drop privileges so the browser lands in
# the desktop session rather than root's.
function Open-PcUrl {
    param([Parameter(Mandatory)][string]$Url)
    try {
        if (-not $IsLinux) {
            Start-Process $Url -ErrorAction Stop
            return
        }
        $opener = @('xdg-open', 'gio', 'sensible-browser') |
            Where-Object { Get-Command $_ -CommandType Application -ErrorAction SilentlyContinue } |
            Select-Object -First 1
        if (-not $opener) {
            Write-Host "`n  Open this address manually: $Url" -ForegroundColor Yellow
            return
        }
        $openArgs = if ($opener -eq 'gio') { @('open', $Url) } else { @($Url) }

        $user = Get-PcDesktopUser
        if ($user -and $user.Name -ne 'root') {
            & sudo -u $user.Name env "DBUS_SESSION_BUS_ADDRESS=$($user.Dbus)" $opener @openArgs 2>&1 | Out-Null
        } else {
            & $opener @openArgs 2>&1 | Out-Null
        }
    } catch {
        Write-Host "`n  [!!] Could not open browser: $_" -ForegroundColor Red
        Write-Host "      Open this address manually: $Url" -ForegroundColor Yellow
    }
}

# Write to both the console and a persistent log file under C:\pcHealth\Logs\ (Windows)
# or ~/pcHealth/Logs/ (Linux).
function Write-PcLog {
    param(
        [string]$Message,
        [switch]$IsError
    )
    try {
        $logDir = if ($IsLinux) {
            Join-Path -Path $env:HOME -ChildPath 'pcHealth' -AdditionalChildPath 'Logs'
        } else {
            Join-Path -Path $env:SystemDrive -ChildPath 'pcHealth' -AdditionalChildPath 'Logs'
        }
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

        $callerScript = (Get-PSCallStack | Where-Object { $_.ScriptName } | Select-Object -Last 1).ScriptName
        $scriptName   = if ($callerScript) {
            [System.IO.Path]::GetFileNameWithoutExtension($callerScript)
        } else { 'pcHealth' }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        "[$timestamp] $Message" | Out-File -FilePath (Join-Path $logDir "$scriptName.log") -Append -ErrorAction Stop
    } catch {
        Write-Debug "Write-PcLog: failed to write to log file: $_"
    }
    if ($IsError) {
        Write-Host $Message -ForegroundColor Red
    } else {
        Write-Host $Message
    }
}

# Parses /etc/os-release and returns a hashtable.
# ID and ID_LIKE are lowercased; NAME and PRETTY_NAME keep original casing.
function Get-LinuxDistroInfo {
    $info = @{}
    if (Test-Path '/etc/os-release') {
        Get-Content '/etc/os-release' | ForEach-Object {
            if ($_ -match '^(\w+)=(.*)$') {
                $info[$Matches[1]] = $Matches[2].Trim('"').Trim("'")
            }
        }
    }
    $info['ID']          = $info['ID']?.ToLower()          ?? ''
    $info['ID_LIKE']     = $info['ID_LIKE']?.ToLower()     ?? ''
    $info['NAME']        = $info['NAME']                   ?? 'Linux'
    $info['PRETTY_NAME'] = $info['PRETTY_NAME']            ?? $info['NAME']
    return $info
}

function Clear-PcHost {
    # [Console]::Clear() fills the entire buffer with spaces and resets the
    # cursor — more reliable than Clear-Host's ANSI escape sequences on Linux,
    # and avoids partial-render artifacts when colour state leaks from tools.
    [Console]::ResetColor()
    [Console]::Clear()
}

$Global:PcTheme = 'Main'

function Set-PcTheme {
    param([string]$Theme)
    $Global:PcTheme = $Theme
    # RawUI colour changes only work in ConsoleHost; skip silently in VS Code,
    # Windows Terminal with transparency, or any other non-standard host.
    if ($Host.Name -ne 'ConsoleHost') { return }
    switch ($Theme) {
        'Main'     { $Host.UI.RawUI.BackgroundColor = 'Black'; $Host.UI.RawUI.ForegroundColor = 'Cyan'   }
        'Tools'    { $Host.UI.RawUI.BackgroundColor = 'Black'; $Host.UI.RawUI.ForegroundColor = 'Red'    }
        'Programs' { $Host.UI.RawUI.BackgroundColor = 'Black'; $Host.UI.RawUI.ForegroundColor = 'Green'  }
        'Action'   { $Host.UI.RawUI.BackgroundColor = 'Black'; $Host.UI.RawUI.ForegroundColor = 'Green'  }
        'Danger'   { $Host.UI.RawUI.BackgroundColor = 'Black'; $Host.UI.RawUI.ForegroundColor = 'Red'    }
        'Warning'  { $Host.UI.RawUI.BackgroundColor = 'Black'; $Host.UI.RawUI.ForegroundColor = 'Yellow' }
    }
}

function Write-PcHeader {
    param([string]$Title)
    $line        = '=' * 60
    $headerColor = switch ($Global:PcTheme) {
        'Main'     { 'Cyan'  }
        'Tools'    { 'Red'   }
        'Programs' { 'Green' }
        default    { 'Cyan'  }
    }
    Write-Host "`n$line" -ForegroundColor $headerColor
    Write-Host "  pcHealth  *  $Global:PcPlatformLabel  *  $Title" -ForegroundColor $headerColor
    Write-Host $line -ForegroundColor $headerColor
    $fullName = try {
        if (-not $IsLinux) {
            (Get-LocalUser -Name $env:USERNAME -ErrorAction SilentlyContinue).FullName
        } else { $null }
    } catch { $null }
    if (-not $fullName) {
        $fullName = if ($IsLinux) { (Get-PcDesktopUser)?.Name } else { $env:USERNAME }
    }
    if (-not $fullName) { $fullName = 'there' }
    $now = Get-Date -Format 'dddd, dd MMMM yyyy  HH:mm'
    Write-Host "  Hello, $fullName!  *  $now`n" -ForegroundColor DarkGray
}

function Write-PcDivider {
    Write-Host ('-' * 60) -ForegroundColor DarkGray
}

function Write-PcOption {
    param([string]$Key, [string]$Label, [string]$Note = '')
    $pad      = ' ' * [Math]::Max(1, 4 - $Key.Length)
    $keyColor = switch ($Global:PcTheme) {
        'Main'     { 'Cyan'   }
        'Tools'    { 'Red'    }
        'Programs' { 'Green'  }
        default    { 'Yellow' }
    }
    Write-Host '  '       -NoNewline
    Write-Host "[$Key]"   -ForegroundColor $keyColor -NoNewline
    Write-Host "$pad$Label" -NoNewline
    if ($Note) { Write-Host "  $Note" -ForegroundColor DarkGray -NoNewline }
    Write-Host ''
}

# Shown after every tool finishes. Returns '1', '2', or '3'.
#   '1' -> stay in current submenu
#   '2' -> return to main menu
#   '3' -> exit the application
function Read-PcNavChoice {
    param([string]$BackLabel = 'Back to previous menu')
    Write-Host ''
    Write-PcDivider
    Write-PcOption '1' $BackLabel
    Write-PcOption '2' 'Main Menu'
    Write-PcOption '3' 'Exit'
    Write-PcDivider
    return (Read-Host "`n  Choice").Trim()
}
