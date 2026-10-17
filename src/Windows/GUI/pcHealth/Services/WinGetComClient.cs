using Microsoft.Management.Deployment;
using NLog;
using System.Runtime.InteropServices;

namespace pcHealth.Services;

/// <summary>
/// The Windows Package Manager over its COM API, so package operations return
/// objects and progress instead of console text.
/// </summary>
/// <remarks>
/// Activation is the awkward part. pcHealth runs unpackaged, self-contained and
/// elevated, and WinGet's manual-activation shim crashes in exactly that
/// combination (microsoft/winget-cli#4377). So the objects are created straight
/// from the out-of-process CLSIDs, and CLSCTX_ALLOW_LOWER_TRUST_REGISTRATION is
/// what lets an administrator process reach a server that runs unelevated. That
/// flag is absent from the API reference but it is WinGet's own: their
/// LocalServerInstanceInitializer sets it for this same reason.
///
/// The shipped projection keeps the I* COM interfaces internal, so their IIDs
/// cannot be named here. Each object is asked for IInspectable instead and
/// CsWinRT maps the runtime class name onto the projected type.
/// </remarks>
internal sealed class WinGetComClient : IWinGet
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    // Out-of-process CLSIDs, from winget-cli's ClassesDefinition.
    private static readonly Guid PackageManagerClsid = new("C53A4F16-787E-42A4-B304-29EFFB4BF597");
    private static readonly Guid FindPackagesOptionsClsid = new("572DED96-9C60-4526-8F92-EE7D91D38C1A");
    private static readonly Guid PackageMatchFilterClsid = new("D02C9DAF-99DC-429C-B503-4E504E4AB000");
    private static readonly Guid InstallOptionsClsid = new("1095F097-EB96-453B-B4E6-1613637F3B14");
    private static readonly Guid CompositeOptionsClsid = new("526534B8-7E46-47C8-8416-B1685C327D37");

    private const uint ClsCtxLocalServer = 0x4;
    private const uint ClsCtxAllowLowerTrustRegistration = 0x4000000;
    private static readonly Guid IInspectableIid = new("AF86E2E0-B12D-4C6A-9C5A-D7AA65101E90");

    private readonly Lazy<PackageManager?> _manager =
        new(TryCreateManager, LazyThreadSafetyMode.ExecutionAndPublication);

    public bool IsNative => _manager.Value is not null;

    public async Task<WinGetResult> InstallAsync(
        string packageId,
        IProgress<WinGetProgress>? progress = null,
        bool force = false,
        CancellationToken ct = default) =>
        await FindThenRunAsync(packageId, upgrade: false, force, progress, ct);

    public async Task<WinGetResult> UpgradeAsync(
        string packageId,
        IProgress<WinGetProgress>? progress = null,
        CancellationToken ct = default) =>
        await FindThenRunAsync(packageId, upgrade: true, force: false, progress, ct);

    public async Task<WinGetResult> UpgradeAllAsync(
        IProgress<WinGetProgress>? progress = null,
        CancellationToken ct = default)
    {
        var manager = Manager;
        var catalog = await ConnectAsync(manager, CompositeSearchBehavior.LocalCatalogs, ct);
        var pending = await UpgradableAsync(catalog, ct);

        if (pending.Count == 0)
            return new WinGetResult(true, "Everything is already up to date.");

        int failed = 0;
        bool reboot = false;
        for (int i = 0; i < pending.Count; i++)
        {
            ct.ThrowIfCancellationRequested();
            var package = pending[i];

            // Each package reports its own download and install percentages;
            // the label carries the position in the queue so one progress bar
            // can stand for the whole run.
            var label = $"{package.Name} ({i + 1} of {pending.Count})";
            // Explicitly typed: a conditional between null and Progress<T> has
            // no natural type to infer.
            IProgress<WinGetProgress>? relay = progress is null
                ? null
                : new Progress<WinGetProgress>(step =>
                    progress.Report(step with { Stage = $"{label}: {step.Stage}" }));

            var result = await RunAsync(manager, upgrade: true, package, force: false, relay, ct);
            if (!result.Succeeded)
            {
                failed++;
                Log.Warn("Upgrade of {Package} failed: {Message}", package.Id, result.Message);
            }
            reboot |= result.RebootRequired;
        }

        return failed == 0
            ? new WinGetResult(true, $"Updated {pending.Count} package(s).", reboot)
            : new WinGetResult(false, $"{pending.Count - failed} of {pending.Count} updated, {failed} failed.", reboot);
    }

    private PackageManager Manager =>
        _manager.Value ?? throw new InvalidOperationException("The WinGet COM server is not available.");

    private async Task<WinGetResult> FindThenRunAsync(
        string packageId,
        bool upgrade,
        bool force,
        IProgress<WinGetProgress>? progress,
        CancellationToken ct)
    {
        var manager = Manager;
        var catalog = await ConnectAsync(manager, CompositeSearchBehavior.RemotePackagesFromAllCatalogs, ct);
        var package = await FindAsync(catalog, packageId, ct);

        return package is null
            ? new WinGetResult(false, $"{packageId} is not in any configured winget source.")
            : await RunAsync(manager, upgrade, package, force, progress, ct);
    }

    private static async Task<WinGetResult> RunAsync(
        PackageManager manager,
        bool upgrade,
        CatalogPackage package,
        bool force,
        IProgress<WinGetProgress>? progress,
        CancellationToken ct)
    {
        var options = Create<InstallOptions>(InstallOptionsClsid);
        options.PackageInstallMode = PackageInstallMode.Silent;
        Optional(() => options.AcceptPackageAgreements = true, nameof(options.AcceptPackageAgreements));
        if (force) Optional(() => options.Force = true, nameof(options.Force));

        var operation = upgrade
            ? manager.UpgradePackageAsync(package, options)
            : manager.InstallPackageAsync(package, options);

        if (progress is not null)
            operation.Progress = (_, state) => progress.Report(Describe(state));

        var result = await operation.AsTask(ct);

        return result.Status == InstallResultStatus.Ok
            ? new WinGetResult(true, upgrade ? "Updated" : "Installed", result.RebootRequired)
            : new WinGetResult(false, Explain(result));
    }

    private static async Task<PackageCatalog> ConnectAsync(
        PackageManager manager,
        CompositeSearchBehavior behavior,
        CancellationToken ct)
    {
        var source = manager.GetPredefinedPackageCatalog(PredefinedPackageCatalog.OpenWindowsCatalog);
        Optional(() => source.AcceptSourceAgreements = true, nameof(source.AcceptSourceAgreements));

        var options = Create<CreateCompositePackageCatalogOptions>(CompositeOptionsClsid);
        options.Catalogs.Add(source);
        options.CompositeSearchBehavior = behavior;

        var connection = await manager.CreateCompositePackageCatalog(options).ConnectAsync().AsTask(ct);
        if (connection.Status != ConnectResultStatus.Ok)
            throw new InvalidOperationException($"Could not open the winget catalog: {connection.Status}.");

        return connection.PackageCatalog;
    }

    private static async Task<CatalogPackage?> FindAsync(
        PackageCatalog catalog,
        string packageId,
        CancellationToken ct)
    {
        var filter = Create<PackageMatchFilter>(PackageMatchFilterClsid);
        filter.Field = PackageMatchField.Id;
        filter.Option = PackageFieldMatchOption.EqualsCaseInsensitive;
        filter.Value = packageId;

        var options = Create<FindPackagesOptions>(FindPackagesOptionsClsid);
        options.Selectors.Add(filter);
        options.ResultLimit = 1;

        var result = await catalog.FindPackagesAsync(options).AsTask(ct);
        return result.Status == FindPackagesResultStatus.Ok && result.Matches.Count > 0
            ? result.Matches[0].CatalogPackage
            : null;
    }

    private static async Task<List<CatalogPackage>> UpgradableAsync(PackageCatalog catalog, CancellationToken ct)
    {
        // No selectors and no filters means the whole catalog, which on a
        // local-behaviour composite is the set of installed packages.
        var options = Create<FindPackagesOptions>(FindPackagesOptionsClsid);
        var result = await catalog.FindPackagesAsync(options).AsTask(ct);

        if (result.Status != FindPackagesResultStatus.Ok)
            throw new InvalidOperationException($"Could not list installed packages: {result.Status}.");

        return result.Matches
            .Select(match => match.CatalogPackage)
            .Where(package => package.IsUpdateAvailable)
            .ToList();
    }

    private static WinGetProgress Describe(InstallProgress state) => state.State switch
    {
        PackageInstallProgressState.Queued => new WinGetProgress("Queued", null),
        PackageInstallProgressState.Downloading => new WinGetProgress("Downloading", Percent(state.DownloadProgress)),
        PackageInstallProgressState.Installing => new WinGetProgress("Installing", Percent(state.InstallationProgress)),
        PackageInstallProgressState.PostInstall => new WinGetProgress("Finishing", null),
        _ => new WinGetProgress("Done", 100),
    };

    // WinGet reports these as a fraction of one.
    private static double Percent(double fraction) => Math.Clamp(fraction * 100, 0, 100);

    private static string Explain(InstallResult result) => result.Status switch
    {
        InstallResultStatus.NoApplicableUpgrade => "Already up to date.",
        InstallResultStatus.NoApplicableInstallers => "No installer for this machine.",
        InstallResultStatus.DownloadError => "The download failed.",
        InstallResultStatus.InstallError => "The installer itself failed. The log has its exit code.",
        InstallResultStatus.BlockedByPolicy => "Blocked by policy.",
        InstallResultStatus.PackageAgreementsNotAccepted => "The package agreements were not accepted.",
        InstallResultStatus.ManifestError => "The package manifest could not be read.",
        InstallResultStatus.CatalogError => "The winget catalog could not be read.",
        _ => $"winget reported {result.Status}.",
    };

    /// <summary>
    /// Set a property that only exists on a later revision of the COM
    /// interface. An older App Installer throws instead of ignoring it, and
    /// our floor is Windows 10 22H2, where it may well be old.
    /// </summary>
    private static void Optional(Action set, string name)
    {
        try
        {
            set();
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "This App Installer does not support {Property}", name);
        }
    }

    private static PackageManager? TryCreateManager()
    {
        try
        {
            return Create<PackageManager>(PackageManagerClsid);
        }
        catch (Exception ex)
        {
            Log.Info(ex, "WinGet COM server unavailable; falling back to winget.exe");
            return null;
        }
    }

    private static T Create<T>(Guid clsid) where T : class
    {
        Guid iid = IInspectableIid;
        int hr = CoCreateInstance(
            ref clsid,
            IntPtr.Zero,
            ClsCtxLocalServer | ClsCtxAllowLowerTrustRegistration,
            ref iid,
            out IntPtr instance);
        Marshal.ThrowExceptionForHR(hr);

        // CreateRcwForComObject adds its own reference. WinGet's own
        // initializer does not release the one obtained here either; a leaked
        // reference per object is the cheaper mistake of the two.
        return (T)WinRT.MarshalInspectable<object>.FromAbi(instance);
    }

    [DllImport("api-ms-win-core-com-l1-1-0.dll", ExactSpelling = true)]
    private static extern int CoCreateInstance(
        ref Guid clsid,
        IntPtr outer,
        uint context,
        ref Guid iid,
        out IntPtr instance);
}
