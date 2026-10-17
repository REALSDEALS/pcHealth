namespace pcHealth.Services;

/// <summary>How the attempt to start the repair ended.</summary>
public sealed record RepairStart(bool Started, string Message);

/// <summary>
/// Starts the "Fix problems using Windows Update" in-place upgrade.
/// </summary>
public interface IWindowsRepair
{
    /// <summary>False when this Windows build has no admin flow host to ask.</summary>
    bool IsSupported { get; }

    /// <summary>Opens Windows Update and asks Windows to begin the repair.</summary>
    Task<RepairStart> StartAsync(CancellationToken ct = default);

    /// <summary>Shows the Recovery page without touching anything.</summary>
    void OpenRecovery();
}
