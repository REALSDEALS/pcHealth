# ============================================================================
# pcHealth -- Windows -- UI Helpers
# Display and navigation utilities used by all menu scripts.
# ============================================================================

# Opens a URL in the user's default browser.
function Open-PcUrl {
    param([Parameter(Mandatory)][string]$Url)
    try {
        Start-Process $Url -ErrorAction Stop
    } catch {
        Write-Host "`n  [!!] Could not open browser: $_" -ForegroundColor Red
        Write-Host "      Open this address manually: $Url" -ForegroundColor Yellow
    }
}

# LTSC and stripped images ship without App Installer. Calling a missing winget
# under $ErrorActionPreference = 'Stop' throws, so tools check first.
function Test-PcWinget {
    if (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue) {
        return $true
    }
    Write-Host "`n[!!] winget is not available on this system." -ForegroundColor Red
    Write-Host "     Use Tools > Repair Winget to install it.`n" -ForegroundColor Yellow
    return $false
}

# Returns 'UEFI', 'BIOS' or 'Unknown'. The PEFirmwareType registry value only
# exists inside Windows PE, so on an installed system the documented
# GetFirmwareType API is the reliable source.
function Get-PcFirmwareType {
    if (-not ('PcHealth.Firmware' -as [type])) {
        Add-Type -Namespace PcHealth -Name Firmware -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetFirmwareType(out uint firmwareType);
'@
    }
    $type = 0
    if (-not [PcHealth.Firmware]::GetFirmwareType([ref]$type)) { return 'Unknown' }
    switch ($type) {
        1       { 'BIOS' }
        2       { 'UEFI' }
        default { 'Unknown' }
    }
}

# Write to both the console and a persistent log file under C:\pcHealth\Logs\.
function Write-PcLog {
    param(
        [string]$Message,
        [switch]$IsError
    )
    try {
        $logDir = Join-Path -Path $env:SystemDrive -ChildPath 'pcHealth' -AdditionalChildPath 'Logs'
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

function Clear-PcHost {
    # [Console]::Clear() fills the entire buffer with spaces and resets the
    # cursor, which avoids partial-render artifacts when colour state leaks
    # out of a tool.
    [Console]::ResetColor()
    # Callers set the theme first; ResetColor just undid it, so put it back
    # before clearing, which also gives the cleared screen the theme colours.
    Set-PcTheme $Global:PcTheme
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
        (Get-LocalUser -Name $env:USERNAME -ErrorAction SilentlyContinue).FullName
    } catch { $null }
    if (-not $fullName) { $fullName = $env:USERNAME }
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
