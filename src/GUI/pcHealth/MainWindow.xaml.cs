using NLog;
using pcHealth.Pages;
using pcHealth.Services;

namespace pcHealth;

public sealed partial class MainWindow : Window
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    private readonly IAppSettings _settings;
    private readonly IUpdateChecker _updateChecker;
    private readonly ICliRunner _cliRunner;

    public MainWindow()
    {
        _settings = App.Services.GetRequiredService<IAppSettings>();
        _updateChecker = App.Services.GetRequiredService<IUpdateChecker>();
        _cliRunner = App.Services.GetRequiredService<ICliRunner>();

        InitializeComponent();

        try
        {
            SystemBackdrop = new MicaBackdrop();
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "Mica backdrop unavailable");
        }

        AppWindow.Resize(new SizeInt32(1100, 720));
        ExtendsContentIntoTitleBar = true;

        var iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "pcHealth.ico");
        if (File.Exists(iconPath))
            AppWindow.SetIcon(iconPath);

        ContentFrame.Navigated += ContentFrame_Navigated;
    }

    private void NavView_Loaded(object sender, RoutedEventArgs e)
    {
        if (NavView.MenuItems.Count > 0)
            NavView.SelectedItem = NavView.MenuItems[0];

        if (_settings.GetBool("AutoCheckVersion", fallback: true))
            _ = CheckForUpdateAsync();
    }

    private async Task CheckForUpdateAsync()
    {
        try
        {
            var tag = await _updateChecker.GetLatestTagAsync();
            if (tag is null || !_updateChecker.IsNewer(tag)) return;

            var dialog = new ContentDialog
            {
                Title = "Update available",
                Content = $"Version {tag.TrimStart('v', 'V')} is available. You are on {_updateChecker.GetCurrentVersion()}.",
                PrimaryButtonText = "Open releases page",
                CloseButtonText = "Later",
                DefaultButton = ContentDialogButton.Primary,
                XamlRoot = ContentFrame.XamlRoot,
            };

            if (await dialog.ShowAsync() == ContentDialogResult.Primary)
                _cliRunner.OpenUri("https://github.com/REALSDEALS/pcHealth/releases/latest");
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "Update check failed");
        }
    }

    private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.IsSettingsSelected)
        {
            NavigateTo("settings");
            return;
        }
        if (args.SelectedItemContainer is NavigationViewItem item)
            NavigateTo(item.Tag?.ToString());
    }

    private void NavView_BackRequested(NavigationView sender, NavigationViewBackRequestedEventArgs args)
    {
        if (ContentFrame.CanGoBack)
            ContentFrame.GoBack();
    }

    private void ContentFrame_Navigated(object sender, NavigationEventArgs args)
    {
        NavView.IsBackEnabled = ContentFrame.CanGoBack;
    }

    internal void NavigateTo(string? tag)
    {
        Type? target = tag switch
        {
            "health" => typeof(HealthPage),
            "tools" => typeof(ToolsPage),
            "programs" => typeof(ProgramsPage),
            "licensekey" => typeof(LicenseKeyPage),
            "settings" => typeof(SettingsPage),
            "info" => typeof(InfoPage),
            _ => null
        };

        if (target is not null && ContentFrame.CurrentSourcePageType != target)
            ContentFrame.Navigate(target, null, new DrillInNavigationTransitionInfo());
    }
}
