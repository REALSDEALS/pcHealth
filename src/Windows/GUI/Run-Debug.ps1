#Requires -Version 7.0
# ============================================================================
# pcHealth -- GUI development runner (Windows)
#
# Builds Debug and runs the app with its log streaming into this terminal,
# the way an IDE does: the process stays in the foreground, every line the
# app writes appears as it happens, and the exit code is decoded when it
# stops.
#
# A WinUI 3 app is a GUI subsystem binary, so it has no console of its own
# and Console.WriteLine goes nowhere. The log is the live feed: NLog.config
# already writes every line to
# %LOCALAPPDATA%\pcHealth\pcHealth_<date>.log, and this tails it from the
# byte where this run started, so nothing from earlier runs is shown.
#
# Use Make-Release.ps1 next to this file for the Release build a user gets,
# and for bootstrapping a machine that has no dependencies yet.
#
# Usage:
#   pwsh -File src/Windows/GUI/Run-Debug.ps1
# ============================================================================

$ErrorActionPreference = 'Stop'

# -- Elevate -------------------------------------------------------------------
# pcHealth's manifest is requireAdministrator, and Start-Process cannot both
# elevate and redirect output. So this window elevates itself first and then
# starts the app as an ordinary child, which keeps the redirection.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    $forwarded = @('-NoExit', '-ExecutionPolicy', 'Bypass', '-NoProfile', '-File', $PSCommandPath)

    Write-Host '[pcHealth] Elevating; the live log continues in the new window.' -ForegroundColor Yellow
    Start-Process -FilePath (Get-Process -Id $PID).Path -Verb RunAs -ArgumentList $forwarded
    exit
}

# -- Project paths -------------------------------------------------------------
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host '[!!] No .NET SDK on PATH. Run Make-Release.ps1 once to install it.' -ForegroundColor Red
    exit 1
}

$projectFile = Join-Path $PSScriptRoot 'pcHealth\pcHealth.csproj'

$rid = if ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq
           [System.Runtime.InteropServices.Architecture]::Arm64) { 'win-arm64' } else { 'win-x64' }

# Read the TargetFramework from the csproj so this path never drifts from it.
$tfm = ([xml](Get-Content $projectFile)).Project.PropertyGroup.TargetFramework |
           Where-Object { $_ } | Select-Object -First 1
$exePath = Join-Path $PSScriptRoot "pcHealth\bin\Debug\$tfm\$rid\pcHealth.exe"

# -- Build ---------------------------------------------------------------------
Write-Host ''
Write-Host "[pcHealth] Building Debug ($rid)..." -ForegroundColor Cyan
dotnet build $projectFile -c Debug -r $rid --nologo -v minimal
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host '[!!] Build failed. The errors are above.' -ForegroundColor Red
    exit 1
}

# -- Log tail ------------------------------------------------------------------
# Reads whole lines only: a writer can be mid-line, and the rest arrives on the
# next pass. Byte offsets rather than characters, so the count stays exact.
function Show-LogTail {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [ref]    $Offset
    )

    if (-not (Test-Path $Path)) { return }

    $stream = [System.IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try {
        # NLog rolls the file at midnight; start over rather than seek past it.
        if ($stream.Length -lt $Offset.Value) { $Offset.Value = 0 }
        if ($stream.Length -eq $Offset.Value) { return }

        $null   = $stream.Seek($Offset.Value, [System.IO.SeekOrigin]::Begin)
        $buffer = [byte[]]::new([int] ($stream.Length - $Offset.Value))
        $read   = $stream.Read($buffer, 0, $buffer.Length)
        $text   = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $read)
    }
    finally { $stream.Dispose() }

    $cut = $text.LastIndexOf("`n")
    if ($cut -lt 0) { return }

    $complete = $text.Substring(0, $cut + 1)
    $Offset.Value += [System.Text.Encoding]::UTF8.GetByteCount($complete)

    foreach ($line in ($complete -split "`r?`n")) {
        if (-not $line) { continue }
        $colour = switch -Regex ($line) {
            '\[(FATAL|ERROR)\]' { 'Red';      break }
            '\[WARN\]'          { 'Yellow';   break }
            '\[INFO\]'          { 'White';    break }
            default             { 'DarkGray' }
        }
        Write-Host $line -ForegroundColor $colour
    }
}

$logDir  = Join-Path $env:LOCALAPPDATA 'pcHealth'
$logFile = Join-Path $logDir ('pcHealth_{0}.log' -f (Get-Date -Format 'yyyy-MM-dd'))

# Start where today's log currently ends, so only this run is shown.
$offset = if (Test-Path $logFile) { (Get-Item $logFile).Length } else { 0 }

# A GUI binary writes nothing here on a good day, but the CLR prints an
# unhandled exception to stderr on its way out, which is worth keeping.
$stdoutFile = Join-Path $env:TEMP 'pcHealth-dev-stdout.log'
$stderrFile = Join-Path $env:TEMP 'pcHealth-dev-stderr.log'

Write-Host ''
Write-Host "[pcHealth] Running  : $exePath"  -ForegroundColor Green
Write-Host "[pcHealth] Log      : $logFile"  -ForegroundColor DarkGray
Write-Host '[pcHealth] Ctrl+C stops the app and this runner.' -ForegroundColor DarkGray
Write-Host ''

$proc = Start-Process -FilePath $exePath -PassThru `
    -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile

try {
    while (-not $proc.HasExited) {
        Show-LogTail -Path $logFile -Offset ([ref] $offset)
        Start-Sleep -Milliseconds 250
    }
}
finally {
    if (-not $proc.HasExited) {
        Write-Host ''
        Write-Host '[pcHealth] Stopping the app...' -ForegroundColor Yellow
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
    # Whatever was written between the last pass and the exit.
    Show-LogTail -Path $logFile -Offset ([ref] $offset)
}

# -- Exit ----------------------------------------------------------------------
foreach ($capture in @(@{ Label = 'stdout'; Path = $stdoutFile }, @{ Label = 'stderr'; Path = $stderrFile })) {
    if ((Test-Path $capture.Path) -and (Get-Item $capture.Path).Length -gt 0) {
        Write-Host ''
        Write-Host "[pcHealth] $($capture.Label):" -ForegroundColor Magenta
        Get-Content $capture.Path | ForEach-Object { Write-Host "  $_" -ForegroundColor Magenta }
    }
    Remove-Item $capture.Path -ErrorAction SilentlyContinue
}

$code = $proc.ExitCode
$hex  = '0x{0:X8}' -f $code

# A native crash never reaches a catch block, so the exit code is the only
# thing that names it. These are the ones worth recognising on sight.
$reason = switch ($hex) {
    '0xC0000005' { 'access violation -- a native crash, which no catch block can hold' }
    '0xC0000409' { 'fail-fast or stack buffer overrun' }
    '0xC000013A' { 'terminated by Ctrl+C' }
    '0xE0434352' { 'unhandled .NET exception' }
    default      { '' }
}

Write-Host ''
if ($code -eq 0) {
    Write-Host '[pcHealth] Exited cleanly (0).' -ForegroundColor Green
}
else {
    Write-Host "[!!] Exited with $code ($hex)" -ForegroundColor Red
    if ($reason) { Write-Host "     $reason" -ForegroundColor Red }
    Write-Host '     Windows records these under Event Viewer > Windows Logs >' -ForegroundColor Yellow
    Write-Host '     Application, source "Application Error" or ".NET Runtime".' -ForegroundColor Yellow
}

exit $code
