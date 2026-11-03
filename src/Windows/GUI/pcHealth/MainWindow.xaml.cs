using Microsoft.UI.Windowing;
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

        // The Settings page saves the theme and applies it on change; without
        // this the choice was lost on every restart.
        if (Content is FrameworkElement root)
            root.RequestedTheme = _settings.Get("AppTheme", "Default") switch
            {
                "Light" => ElementTheme.Light,
                "Dark" => ElementTheme.Dark,
                _ => ElementTheme.Default,
            };

        try
        {
            SystemBackdrop = new MicaBackdrop();
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "Mica backdrop unavailable");
        }

        AppWindow.Resize(new SizeInt32(1100, 720));

        // Title bar customization is Windows 11 only -- IsCustomizationSupported()
        // returns false on Windows 10, where the fallback behaviour differs per
        // Windows App SDK version. Keep the system caption there instead.
        if (AppWindowTitleBar.IsCustomizationSupported())
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

    // SelectionChanged does not fire when the selected item is clicked again,
    // so with a tool page open (reached from Tools), clicking "Tools" did
    // nothing. ItemInvoked fires on every click; NavigateTo ignores a click
    // on the page that is already showing.
    private void NavView_ItemInvoked(NavigationView sender, NavigationViewItemInvokedEventArgs args)
    {
        if (args.IsSettingsInvoked)
            NavigateTo("settings");
        else if (args.InvokedItemContainer is NavigationViewItem item)
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

        // Going Back to a top-level page must move the sidebar highlight too,
        // or it keeps pointing at the page that was left.
        var tag = TagFor(args.SourcePageType);
        if (tag == "settings")
            NavView.SelectedItem = NavView.SettingsItem;
        else if (tag is not null)
            NavView.SelectedItem = NavView.MenuItems.Concat(NavView.FooterMenuItems)
                .OfType<NavigationViewItem>()
                .FirstOrDefault(i => i.Tag?.ToString() == tag) ?? NavView.SelectedItem;

        // Every menu click and every drill-in passes through here, so this one
        // line is what makes a log read like a session rather than a crash dump.
        Log.Info("Navigated to {Page}", args.SourcePageType.Name);
    }

    private static readonly Dictionary<string, Type> TopLevelPages = new()
    {
        ["health"] = typeof(HealthPage),
        ["tools"] = typeof(ToolsPage),
        ["programs"] = typeof(ProgramsPage),
        ["settings"] = typeof(SettingsPage),
        ["info"] = typeof(InfoPage),
    };

    private static string? TagFor(Type page) =>
        TopLevelPages.FirstOrDefault(p => p.Value == page).Key;

    internal void NavigateTo(string? tag)
    {
        if (tag is not null && TopLevelPages.TryGetValue(tag, out var target)
            && ContentFrame.CurrentSourcePageType != target)
            ContentFrame.Navigate(target, null, new DrillInNavigationTransitionInfo());
    }
}
