using NLog;

namespace pcHealth.Services;

/// <summary>
/// winget.exe, used only when the COM server cannot be reached.
/// </summary>
/// <remarks>
/// This is the path the whole app used to take. Its output is a progress bar
/// that redraws itself through the pipe and prose that changes with the
/// locale, so the only honest thing to do with a line is show it: there is no
/// percentage to recover and no status worth parsing out of it.
/// </remarks>
internal sealed class WinGetCliClient : IWinGet
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();
    private const string Agreements = "--accept-source-agreements --accept-package-agreements";

    private readonly IProcessRunner _runner;

    public WinGetCliClient(IProcessRunner runner) => _runner = runner;

    public bool IsNative => false;

    public Task<WinGetResult> InstallAsync(
        string packageId,
        IProgress<WinGetProgress>? progress = null,
        bool force = false,
        CancellationToken ct = default) =>
        RunAsync($"install --id {packageId} {Agreements}" + (force ? " --force" : ""), "Installed", progress, ct);

    public Task<WinGetResult> UpgradeAsync(
        string packageId,
        IProgress<WinGetProgress>? progress = null,
        CancellationToken ct = default) =>
        RunAsync($"upgrade --id {packageId} {Agreements}", "Updated", progress, ct);

    public Task<WinGetResult> UpgradeAllAsync(
        IProgress<WinGetProgress>? progress = null,
        CancellationToken ct = default) =>
        RunAsync($"upgrade --all {Agreements}", "Up to date.", progress, ct);

    private async Task<WinGetResult> RunAsync(
        string arguments,
        string done,
        IProgress<WinGetProgress>? progress,
        CancellationToken ct)
    {
        try
        {
            int exitCode = await _runner.RunAsync("winget.exe", arguments, line =>
            {
                Log.Debug("winget: {Line}", line);
                // A bar of block characters is not a sentence; anything else
                // is the closest thing to a status this path can offer.
                if (line.Length > 3 && !line.TrimStart().StartsWith('\u2588'))
                    progress?.Report(new WinGetProgress(line.Trim(), null));
            }, ct);

            return exitCode == 0
                ? new WinGetResult(true, done)
                : new WinGetResult(false, $"winget exited with code {exitCode}.");
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "winget.exe failed: {Arguments}", arguments);
            return new WinGetResult(false, "Could not run winget. Is App Installer present?");
        }
    }
}
