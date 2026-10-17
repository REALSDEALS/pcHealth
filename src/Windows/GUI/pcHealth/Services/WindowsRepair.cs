using NLog;
using System.Diagnostics;

namespace pcHealth.Services;

/// <summary>
/// Starts the Windows Update in-place upgrade by running the same command the
/// Settings app runs.
/// </summary>
/// <remarks>
/// Settings has no API for this repair, so pcHealth used to press its button
/// through UI Automation. Watching what the button actually does showed there
/// was no need: it runs
///
///     SystemSettingsAdminFlows.exe RunInPlaceUpgrade Recoverypage
///
/// and the servicing stack picks it up from there. Running the same command
/// removes the dependency on another app's layout, its display language and
/// its element tree, all of which could change under us. The second argument
/// is the page Settings reports as the origin; it is passed exactly as
/// observed rather than invented.
///
/// The verb is undocumented, so a build without it must fail visibly instead
/// of silently doing nothing -- hence the exit code check and IsSupported.
/// </remarks>
internal sealed class WindowsRepair : IWindowsRepair
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    private const string Verb = "RunInPlaceUpgrade";
    private const string Origin = "Recoverypage";

    // The host hands off to TrustedInstaller and exits; it does not sit around
    // for the hour the repair itself takes.
    private static readonly TimeSpan HandoffTimeout = TimeSpan.FromSeconds(30);

    // How long to give Settings to come up before asking anyway.
    private static readonly TimeSpan SettingsTimeout = TimeSpan.FromSeconds(15);
    private static readonly TimeSpan PollInterval = TimeSpan.FromMilliseconds(250);
    private static readonly TimeSpan SettleDelay = TimeSpan.FromSeconds(2);

    // Windows decides in its own dialog, and its exit code is the same either
    // way, so this must not claim the repair is running.
    private const string HandedOff =
        "Windows is handling it from here. Confirm the prompt it shows to start the download; "
        + "closing that prompt leaves the machine untouched.";

    private readonly ICliRunner _cli;

    public WindowsRepair(ICliRunner cli) => _cli = cli;

    private static string HostPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.System),
        "SystemSettingsAdminFlows.exe");

    public bool IsSupported => File.Exists(HostPath);

    public void OpenRecovery() => _cli.OpenUri("ms-settings:recovery");

    public async Task<RepairStart> StartAsync(CancellationToken ct = default)
    {
        if (!IsSupported)
        {
            return new RepairStart(false,
                "This Windows build has no SystemSettingsAdminFlows.exe, so the repair cannot be started from here.");
        }

        // The admin flow shows its dialog inside Settings, so with Settings
        // closed the command returns without asking anything. Opening the page
        // first also puts the download where the user can watch it.
        _cli.OpenUri("ms-settings:windowsupdate");
        await WaitForSettingsAsync(ct);

        var info = new ProcessStartInfo(HostPath)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        info.ArgumentList.Add(Verb);
        info.ArgumentList.Add(Origin);

        try
        {
            using var process = Process.Start(info);
            if (process is null)
            {
                return new RepairStart(false, "Windows would not start the repair host.");
            }

            Log.Info("Started {Host} {Verb} {Origin}", HostPath, Verb, Origin);

            // A quick non-zero exit means the verb was rejected. Still running
            // after the timeout is normal: the dialog is waiting on the user.
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeout.CancelAfter(HandoffTimeout);
            try
            {
                await process.WaitForExitAsync(timeout.Token);
            }
            catch (OperationCanceledException) when (!ct.IsCancellationRequested)
            {
                return new RepairStart(true, HandedOff);
            }

            if (process.ExitCode != 0)
            {
                Log.Warn("Repair host exited with {Code}", process.ExitCode);
                return new RepairStart(false,
                    $"Windows refused the repair (exit code {process.ExitCode}). Check Windows Update for an update already in progress.");
            }

            Log.Info("Repair host exited with 0");
            return new RepairStart(true, HandedOff);
        }
        catch (System.ComponentModel.Win32Exception ex)
        {
            Log.Error(ex, "Could not run the repair host");
            return new RepairStart(false, $"Could not run the repair host: {ex.Message}");
        }
    }

    private static async Task WaitForSettingsAsync(CancellationToken ct)
    {
        var deadline = DateTime.UtcNow + SettingsTimeout;
        while (DateTime.UtcNow < deadline && !SettingsIsRunning())
        {
            await Task.Delay(PollInterval, ct);
        }

        // Being in the process list is not the same as being ready to broker a
        // call, and there is nothing to poll for that.
        await Task.Delay(SettleDelay, ct);
    }

    private static bool SettingsIsRunning()
    {
        var running = Process.GetProcessesByName("SystemSettings");
        foreach (var p in running) p.Dispose();
        return running.Length > 0;
    }
}
