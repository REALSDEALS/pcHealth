#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Finds what the Settings "Reinstall now" button calls under the hood.

.DESCRIPTION
    Windows publishes no API for the "Fix problems using Windows Update" repair,
    so pcHealth presses the real button through UI Automation. This script looks
    for something better: the binary, setting id or registry flag the button
    actually uses, so the repair could be started directly instead.

    Everything here is read-only. Nothing in this script starts a repair -- Watch
    asks you to press the button yourself and reports what moved.

    A warning about false leads: ResetEngine.dll is full of promising words like
    CloudDownloadConnection and GenerateReinstallList, but every one of them
    belongs to PushButtonReset -- "Reset this PC". That wipes the machine and is
    not the repair. Judge a hit by the feature it belongs to, not by its name.

.PARAMETER Mode
    Settings scans for the Settings page's own setting ids.
    Strings scans the likely binaries for revealing text.
    Protocols lists the ms- URI schemes this machine registers.
    Watch records what happens while you press the button.
    All runs everything.

.PARAMETER WatchSeconds
    How long Watch records. The repair takes a while to get going, so this is
    generous by default.

.EXAMPLE
    .\Find-RepairTrigger.ps1 -Mode Settings

.EXAMPLE
    .\Find-RepairTrigger.ps1 -Mode Watch -WatchSeconds 420
#>
[CmdletBinding()]
param(
    [ValidateSet('Settings', 'Strings', 'Protocols', 'Watch', 'Deep', 'Locate', 'Hunt', 'All')]
    [string]$Mode = 'All',

    [ValidateRange(30, 1800)]
    [int]$WatchSeconds = 300,

    # Deep mode: the binary to read. Locate mode: the file name to find.
    [string]$File,
    [string]$Pattern = 'Ipu|Uso|Orchestrator|Reinstall|Repair|Recovery|IUpdate'
)

Set-StrictMode -Version Latest

# Processes worth shouting about: these are the ones the button reaches for.
$NotableProcess = 'SystemSettingsAdminFlows|MoUsoCoreWorker|usoclient|UsoCoreWorker|TiWorker|TrustedInstaller|SetupHost|WaaSMedic'

# Words worth finding in a binary that knows about this repair.
# Matched case-sensitively, which is what keeps Ipu from hitting "manIPULation".
$InterestingPattern = 'Reinstall|CloudDownload|RepairVersion|SelfHeal|RecoveryReinstall|FixProblem|' +
                      'ms-settings:recovery|StartRepair|RemediationRequired|ms-cxh|' +
                      'Ipu[A-Z]|IpuInitiated|AdminFlow|Orchestrator|UpdateSessionOrchestrator|UsoSvc'

# Settings names every control it owns as SystemSettings_<Area>_<Setting>, so
# the repair button has an id of its own and that id is the real lead.
$SettingIdPattern = 'SystemSettings_[A-Za-z0-9_]*(Recovery|Reinstall|Repair|Reset|Update|Ipu)[A-Za-z0-9_]*'

function Get-BinaryString {
    <#
        .SYNOPSIS
            Pulls printable runs out of a file and returns the ones that match.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern,
        [int]$MinimumLength = 6
    )

    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
    }
    catch [System.IO.IOException] {
        Write-Warning "Could not read $Path : $($_.Exception.Message)"
        return
    }
    catch [System.UnauthorizedAccessException] {
        Write-Warning "Access denied reading $Path"
        return
    }

    # A PE carries literals both as plain bytes and as UTF-16, so both decodings
    # are searched rather than guessing which one a given string used. UTF-16 is
    # decoded from byte 0 and byte 1, because a string starting at an odd offset
    # is garbled by the other alignment and would be missed entirely.
    $runPattern = "[\x20-\x7E]{$MinimumLength,}"
    foreach ($text in @(
        [System.Text.Encoding]::ASCII.GetString($bytes),
        [System.Text.Encoding]::Unicode.GetString($bytes),
        [System.Text.Encoding]::Unicode.GetString($bytes, 1, $bytes.Length - 1)
    )) {
        foreach ($match in [regex]::Matches($text, $runPattern)) {
            if ($match.Value -cnotmatch $Pattern) { continue }

            # One blob of concatenated error names can be tens of kilobytes and
            # tells us nothing, so long runs are clipped rather than dumped.
            if ($match.Value.Length -gt 160) {
                Write-Output ($match.Value.Substring(0, 160) + ' [clipped]')
            }
            else {
                Write-Output $match.Value
            }
        }
    }
}

function Get-ScanCandidate {
    <#
        .SYNOPSIS
            The binaries worth reading, as full paths, deduplicated.
    #>
    [CmdletBinding()]
    param([switch]$SettingsOnly)

    $system32 = Join-Path $env:SystemRoot 'System32'

    $named = if ($SettingsOnly) {
        @('SystemSettings.Handlers.dll', 'SystemSettings.DataModel.dll', 'SystemSettings.dll')
    }
    else {
        @(
            'SystemSettings.Handlers.dll', 'SystemSettings.DataModel.dll', 'SystemSettings.dll',
            'SystemSettingsAdminFlows.exe',
            'usoclient.exe', 'UsoCore.dll', 'MoUsoCoreWorker.exe', 'usocoreworker.exe',
            'SystemReset.exe', 'ResetEngine.dll', 'ResetEngOnline.dll', 'wuaueng.dll'
        )
    }

    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $named) { $paths.Add((Join-Path $system32 $name)) }

    # SystemSettings.Handlers.dll only launches the admin flow host; the real
    # per-area handlers are separate DLLs sitting next to it.
    foreach ($glob in @('SettingsHandlers*.dll', 'SystemSettings*.dll', '*Uso*.dll', '*Uso*.exe')) {
        Get-ChildItem -LiteralPath $system32 -Filter $glob -File -ErrorAction SilentlyContinue |
            ForEach-Object { $paths.Add($_.FullName) }
    }

    $folders = @((Join-Path $env:SystemRoot 'ImmersiveControlPanel'))
    if (-not $SettingsOnly) {
        $folders += (Join-Path $env:SystemRoot 'SystemApps')
        $folders += (Join-Path $env:SystemRoot 'UUS')
    }

    foreach ($folder in $folders) {
        if (-not (Test-Path -LiteralPath $folder)) { continue }
        Get-ChildItem -LiteralPath $folder -Filter '*.dll' -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Directory.Name -notlike '*Edge*' } |
            ForEach-Object { $paths.Add($_.FullName) }
    }

    Write-Output ($paths | Sort-Object -Unique)
}

function Invoke-Scan {
    <#
        .SYNOPSIS
            Scans a candidate set and reports missing files as well as hits, so
            "no output" cannot be mistaken for "no matches".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Candidate,
        [Parameter(Mandatory)][string]$Pattern
    )

    $scanned = 0
    $missing = [System.Collections.Generic.List[string]]::new()
    $hitFiles = 0

    foreach ($path in $Candidate) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $found = @(Join-Path $env:SystemRoot 'System32'), (Join-Path $env:SystemRoot 'UUS') |
                Where-Object { Test-Path -LiteralPath $_ } |
                ForEach-Object {
                    Get-ChildItem -LiteralPath $_ -Filter (Split-Path -Leaf $path) -Recurse -File -ErrorAction SilentlyContinue
                } |
                Select-Object -First 1
            if ($null -eq $found) {
                $missing.Add($path)
                continue
            }
            $path = $found.FullName
        }
        $scanned++

        $hits = @(Get-BinaryString -Path $path -Pattern $Pattern | Sort-Object -Unique)
        if ($hits.Count -eq 0) { continue }

        $hitFiles++
        Write-Host ''
        Write-Host ("--- {0} ({1} hits)" -f $path, $hits.Count) -ForegroundColor Yellow
        $hits | ForEach-Object { Write-Host "    $_" }
    }

    Write-Host ''
    Write-Host ("Read {0} files, {1} had hits." -f $scanned, $hitFiles)
    if ($missing.Count -gt 0) {
        Write-Host ("{0} candidate(s) were not on this machine:" -f $missing.Count) -ForegroundColor DarkYellow
        $missing | ForEach-Object { Write-Host "    $_" }
    }
}

function Invoke-SettingIdScan {
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host '== Settings page ids around recovery and repair ==' -ForegroundColor Cyan
    Write-Host 'The button has an id of its own; that id is the lead worth chasing.'

    Invoke-Scan -Candidate @(Get-ScanCandidate -SettingsOnly) -Pattern $SettingIdPattern
}

function Invoke-StringScan {
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host '== Binaries mentioning repair-ish things ==' -ForegroundColor Cyan
    Write-Host 'Remember: PushButtonReset hits belong to "Reset this PC", not to the repair.' -ForegroundColor DarkYellow

    Invoke-Scan -Candidate @(Get-ScanCandidate) -Pattern $InterestingPattern
}

function Invoke-ProtocolScan {
    <#
        .SYNOPSIS
            Lists the ms- URI schemes this machine registers, with the command
            each one really runs.

        .DESCRIPTION
            Read-only. Nothing is launched: some of these verbs start
            destructive flows, so they are only printed.
    #>
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host '== Registered ms- URI schemes ==' -ForegroundColor Cyan
    Write-Host 'Read-only. Do not fire these blindly: some of them reset the PC.' -ForegroundColor DarkYellow

    Get-ChildItem -LiteralPath 'Registry::HKEY_CLASSES_ROOT' -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -like 'ms-*' } |
        ForEach-Object {
            $scheme = $_.PSChildName
            $values = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            if ($null -eq $values) { return }
            if ($values.PSObject.Properties.Name -notcontains 'URL Protocol') { return }

            # Each scheme gets its own lookup; a shared variable would carry the
            # previous scheme's command over whenever a key has none.
            $command = '(no open command)'
            $commandKey = Join-Path $_.PSPath 'shell\open\command'
            if (Test-Path -LiteralPath $commandKey) {
                $item = Get-ItemProperty -LiteralPath $commandKey -ErrorAction SilentlyContinue
                if ($null -ne $item -and $item.PSObject.Properties.Name -contains '(default)') {
                    $command = $item.'(default)'
                }
            }

            Write-Host ('    {0,-34} {1}' -f $scheme, $command)
        }
}

function Invoke-DeepScan {
    <#
        .SYNOPSIS
            Dumps one binary's strings against a pattern you choose.

        .DESCRIPTION
            The broad scan answers "which file knows about this". This answers
            "what exactly does that file say", which is the next question every
            time the broad scan points somewhere.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Match
    )

    Write-Host ''
    Write-Host ("== Deep read of {0} ==" -f $Path) -ForegroundColor Cyan
    Write-Host ("Pattern (case-sensitive): {0}" -f $Match)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Host '    File not found.' -ForegroundColor Red
        return
    }

    $hits = @(Get-BinaryString -Path $Path -Pattern $Match -MinimumLength 4 | Sort-Object -Unique)
    Write-Host ("{0} distinct matches." -f $hits.Count) -ForegroundColor Yellow
    $hits | ForEach-Object { Write-Host "    $_" }
}

function Invoke-Locate {
    <#
        .SYNOPSIS
            Finds a file anywhere under the Windows directory.

        .DESCRIPTION
            Guessing a path wastes a round trip. MoUsoCoreWorker plainly exists,
            since it runs, so the machine can simply be asked where it is.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    Write-Host ''
    Write-Host ("== Looking for {0} under {1} ==" -f $Name, $env:SystemRoot) -ForegroundColor Cyan

    $found = @(
        Get-ChildItem -LiteralPath $env:SystemRoot -Filter $Name -Recurse -File -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName
    )

    if ($found.Count -eq 0) {
        Write-Host '    Not found.' -ForegroundColor Red
        Write-Host '    If it is running, this gives the path directly:'
        Write-Host ("    Get-Process {0} | Select-Object -Unique Path" -f [System.IO.Path]::GetFileNameWithoutExtension($Name))
        return
    }

    $found | ForEach-Object { Write-Host "    $_" -ForegroundColor Green }
}

function Invoke-Hunt {
    <#
        .SYNOPSIS
            Reads every binary under System32 looking for one pattern.

        .DESCRIPTION
            The slow, last-resort sweep, for when a distinctive string is known
            but not which file writes it. Opt-in because it reads gigabytes.
        #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Match)

    Write-Host ''
    Write-Host ("== Sweeping System32 for {0} ==" -f $Match) -ForegroundColor Cyan
    Write-Host 'This reads a lot of files and takes a few minutes.' -ForegroundColor DarkYellow

    $files = @(
        Get-ChildItem -LiteralPath (Join-Path $env:SystemRoot 'System32') -Include '*.dll', '*.exe' `
            -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -lt 40MB }
    )
    Write-Host ("{0} files to read." -f $files.Count)

    $index = 0
    $hitCount = 0
    foreach ($file in $files) {
        $index++
        if ($index % 250 -eq 0) {
            Write-Host ("    ... {0}/{1}, {2} file(s) with hits" -f $index, $files.Count, $hitCount) -ForegroundColor DarkGray
        }

        $hits = @(Get-BinaryString -Path $file.FullName -Pattern $Match -MinimumLength 4 | Sort-Object -Unique)
        if ($hits.Count -eq 0) { continue }

        $hitCount++
        Write-Host ''
        Write-Host ("--- {0}" -f $file.FullName) -ForegroundColor Yellow
        $hits | ForEach-Object { Write-Host "    $_" }
    }

    Write-Host ''
    Write-Host ("Swept {0} files, {1} had hits." -f $files.Count, $hitCount)
}

function Get-UpdateRegistrySnapshot {
    <#
        .SYNOPSIS
            Flattens the Windows Update keys into comparable "key|name=value" lines.
    #>
    [CmdletBinding()]
    param()

    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\WindowsUpdate',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate'
    )

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }

        $keys = @($root) + @(
            Get-ChildItem -LiteralPath $root -Recurse -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty PSPath
        )

        foreach ($key in $keys) {
            $values = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
            if ($null -eq $values) { continue }

            foreach ($property in $values.PSObject.Properties) {
                if ($property.Name -like 'PS*') { continue }
                Write-Output ('{0}|{1}={2}' -f $key, $property.Name, ($property.Value -join ','))
            }
        }
    }
}

function Get-OrchestratorTask {
    <#
        .SYNOPSIS
            Lists the Update Orchestrator task files, read off disk so no
            Windows-only cmdlet is needed.
    #>
    [CmdletBinding()]
    param()

    $tasks = Join-Path $env:SystemRoot 'System32\Tasks\Microsoft\Windows\UpdateOrchestrator'
    if (-not (Test-Path -LiteralPath $tasks)) { return }

    Get-ChildItem -LiteralPath $tasks -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
}

function Invoke-ButtonWatch {
    <#
        .SYNOPSIS
            Reports what starts and what changes while you press the button.

        .DESCRIPTION
            Processes are polled rather than subscribed to. An indication
            subscription printed nothing until it ended, which looks identical
            to finding nothing; polling shows each new process the moment it
            appears, so the screen proves the watch is alive.
    #>
    [CmdletBinding()]
    param([int]$Seconds)

    Write-Host ''
    Write-Host '== Recording what the button does ==' -ForegroundColor Cyan

    $registryBefore = @(Get-UpdateRegistrySnapshot)
    $tasksBefore = @(Get-OrchestratorTask)
    Write-Host ("Baseline: {0} registry values, {1} orchestrator tasks." -f $registryBefore.Count, $tasksBefore.Count)

    $known = @{}
    foreach ($process in Get-CimInstance -ClassName Win32_Process -ErrorAction SilentlyContinue) {
        $known[$process.ProcessId] = $true
    }

    Write-Host ''
    Write-Host 'Now press "Reinstall now" in Settings > System > Recovery.' -ForegroundColor Green
    Write-Host ("Watching for {0} seconds. New processes appear below as they start." -f $Seconds)
    Write-Host ''

    $started = [System.Collections.Generic.List[string]]::new()
    $deadline = (Get-Date).AddSeconds($Seconds)
    $lastTick = Get-Date

    try {
    while ((Get-Date) -lt $deadline) {
        foreach ($process in Get-CimInstance -ClassName Win32_Process -ErrorAction SilentlyContinue) {
            if ($known.ContainsKey($process.ProcessId)) { continue }
            $known[$process.ProcessId] = $true
            $started.Add($process.Name)

            $colour = if ($process.Name -match $NotableProcess) { 'Magenta' } else { 'Green' }
            Write-Host ('    {0:HH:mm:ss}  {1} (pid {2})' -f (Get-Date), $process.Name, $process.ProcessId) -ForegroundColor $colour

            $line = if ([string]::IsNullOrWhiteSpace($process.CommandLine)) { $process.ExecutablePath } else { $process.CommandLine }
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                Write-Host ('             {0}' -f $line) -ForegroundColor DarkGray
            }
        }

        # A heartbeat every 30s, so a quiet stretch still looks like progress.
        if (((Get-Date) - $lastTick).TotalSeconds -ge 30) {
            $lastTick = Get-Date
            $remaining = [int]($deadline - (Get-Date)).TotalSeconds
            Write-Host ("    ... still watching, {0}s left" -f $remaining) -ForegroundColor DarkGray
        }

        Start-Sleep -Milliseconds 700
    }
    }
    finally {

    Write-Host ''
    Write-Host '--- Processes started while watching ---' -ForegroundColor Yellow
    if ($started.Count -eq 0) {
        Write-Host '    (none)'
    }
    else {
        $started | Group-Object | Sort-Object -Property Count -Descending |
            ForEach-Object { Write-Host ('    {0,-40} x{1}' -f $_.Name, $_.Count) }
    }

    Write-Host ''
    Write-Host '--- Windows Update registry values that changed ---' -ForegroundColor Yellow
    $registryDelta = @(Compare-Object -ReferenceObject $registryBefore -DifferenceObject @(Get-UpdateRegistrySnapshot))
    if ($registryDelta.Count -eq 0) {
        Write-Host '    (nothing changed)'
    }
    else {
        foreach ($change in $registryDelta) {
            $sign = if ($change.SideIndicator -eq '=>') { 'new ' } else { 'gone' }
            Write-Host ('    [{0}] {1}' -f $sign, $change.InputObject)
        }
    }

    Write-Host ''
    Write-Host '--- Update Orchestrator tasks that appeared ---' -ForegroundColor Yellow
    $tasksDelta = @(
        Compare-Object -ReferenceObject $tasksBefore -DifferenceObject @(Get-OrchestratorTask) |
            Where-Object { $_.SideIndicator -eq '=>' }
    )
    if ($tasksDelta.Count -eq 0) {
        Write-Host '    (none)'
    }
    else {
        $tasksDelta | ForEach-Object { Write-Host ('    {0}' -f $_.InputObject) }
    }

    }
}

Write-Host 'pcHealth -- repair trigger hunt (read-only)' -ForegroundColor Cyan

if ($Mode -in @('Settings', 'All')) { Invoke-SettingIdScan }
if ($Mode -in @('Protocols', 'All')) { Invoke-ProtocolScan }
if ($Mode -in @('Strings', 'All')) { Invoke-StringScan }
if ($Mode -eq 'Deep') {
    if ([string]::IsNullOrWhiteSpace($File)) {
        Write-Host 'Deep mode needs -File, for example:' -ForegroundColor Red
        Write-Host '    .\Find-RepairTrigger.ps1 -Mode Deep -File "$env:SystemRoot\System32\SystemSettings.Handlers.dll"'
    }
    else {
        Invoke-DeepScan -Path $File -Match $Pattern
    }
}
if ($Mode -eq 'Locate') {
    if ([string]::IsNullOrWhiteSpace($File)) {
        Write-Host 'Locate mode needs -File, for example -File "MoUsoCoreWorker.exe"' -ForegroundColor Red
    }
    else {
        Invoke-Locate -Name $File
    }
}
if ($Mode -eq 'Hunt') { Invoke-Hunt -Match $Pattern }
if ($Mode -in @('Watch', 'All')) { Invoke-ButtonWatch -Seconds $WatchSeconds }

Write-Host ''
Write-Host 'Done. Send the output back so the findings can be turned into a direct call.' -ForegroundColor Cyan
