using Microsoft.Extensions.DependencyInjection;
using NLog;
using pcHealth.Services;
using pcHealth.ViewModels;

namespace pcHealth;

public partial class App : Application
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    public static IServiceProvider Services { get; private set; } = null!;
    internal static MainWindow? MainWindow { get; private set; }

    public App()
    {
        ConfigureServices();
        InitializeComponent();
        UnhandledException += OnUnhandledException;
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        MainWindow = new MainWindow();
        MainWindow.Activate();
    }

    private static void ConfigureServices()
    {
        var s = new ServiceCollection();

        // Infrastructure services
        s.AddSingleton<IAppSettings, AppSettings>();
        s.AddSingleton<ICliRunner, CliRunner>();
        s.AddSingleton<IUpdateChecker, UpdateChecker>();
        s.AddSingleton<IProcessRunner, ProcessRunner>();

        // ViewModels — Transient: elke navigatie krijgt een frisse instantie
        s.AddTransient<AudioRestartViewModel>();
        s.AddTransient<BatteryReportViewModel>();
        s.AddTransient<BIOSPasswordViewModel>();
        s.AddTransient<BootRepairViewModel>();
        s.AddTransient<CBSLogViewModel>();
        s.AddTransient<DiskCleanupViewModel>();
        s.AddTransient<DiskOptimizationViewModel>();
        s.AddTransient<HardwareInfoViewModel>();
        s.AddTransient<HealthViewModel>();
        s.AddTransient<HPUpdateViewModel>();
        s.AddTransient<InfoViewModel>();
        s.AddTransient<LicenseKeyViewModel>();
        s.AddTransient<NetworkContinuousViewModel>();
        s.AddTransient<NetworkPingViewModel>();
        s.AddTransient<NetworkResetViewModel>();
        s.AddTransient<NiniteViewModel>();
        s.AddTransient<OpenBatteryReportViewModel>();
        s.AddTransient<PowerOptionsViewModel>();
        s.AddTransient<ProgramsViewModel>();
        s.AddTransient<ScanRepairViewModel>();
        s.AddTransient<SettingsViewModel>();
        s.AddTransient<SystemInfoViewModel>();
        s.AddTransient<SystemUpdateViewModel>();
        s.AddTransient<ToolsViewModel>();
        s.AddTransient<TracerouteViewModel>();
        s.AddTransient<WindowsUpdateViewModel>();
        s.AddTransient<WingetRepairViewModel>();

        Services = s.BuildServiceProvider();
    }

    private static void OnUnhandledException(object sender, Microsoft.UI.Xaml.UnhandledExceptionEventArgs e)
    {
        Log.Fatal(e.Exception, "Unhandled exception");
        LogManager.Flush();
        e.Handled = false;
    }
}
