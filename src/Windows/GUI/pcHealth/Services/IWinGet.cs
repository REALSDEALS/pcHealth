namespace pcHealth.Services;

/// <summary>One step of a package operation, as the COM API reports it.</summary>
/// <param name="Stage">What winget is doing right now: Downloading, Installing, …</param>
/// <param name="Percent">0-100, or null when the stage has no measurable progress.</param>
public sealed record WinGetProgress(string Stage, double? Percent);

/// <summary>How a package operation ended.</summary>
public sealed record WinGetResult(bool Succeeded, string Message, bool RebootRequired = false);

/// <summary>
/// Package management through the Windows Package Manager.
/// </summary>
/// <remarks>
/// Implementations talk to the WinGet COM API where they can. winget.exe writes
/// a redrawing progress bar to a pipe and its text changes with the locale, so
/// it is the fallback rather than the contract.
/// </remarks>
public interface IWinGet
{
    /// <summary>False when the COM API could not be reached and winget.exe is being used instead.</summary>
    bool IsNative { get; }

    Task<WinGetResult> InstallAsync(
        string packageId,
        IProgress<WinGetProgress>? progress = null,
        bool force = false,
        CancellationToken ct = default);

    Task<WinGetResult> UpgradeAsync(
        string packageId,
        IProgress<WinGetProgress>? progress = null,
        CancellationToken ct = default);

    Task<WinGetResult> UpgradeAllAsync(
        IProgress<WinGetProgress>? progress = null,
        CancellationToken ct = default);
}
