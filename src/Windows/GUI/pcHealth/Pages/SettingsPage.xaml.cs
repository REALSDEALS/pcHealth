using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class SettingsPage : Page
{
    public SettingsViewModel ViewModel { get; } = App.Services.GetRequiredService<SettingsViewModel>();
    private bool _isLoaded;

    public SettingsPage()
    {
        InitializeComponent();
        ThemeCombo.SelectedIndex = ViewModel.Theme switch { "Light" => 1, "Dark" => 2, _ => 0 };
        AutoReinstallToggle.IsOn = ViewModel.AutoReinstall;
        AutoUpdateCheckToggle.IsOn = ViewModel.AutoCheckVersion;
        _isLoaded = true;
    }

    private void ThemeCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (!_isLoaded) return;
        if (ThemeCombo.SelectedItem is not ComboBoxItem item) return;
        var tag = item.Tag?.ToString() ?? "Default";
        ViewModel.Theme = tag;

        // Applying the theme requires XamlRoot, so it stays in code-behind.
        var requestedTheme = tag switch
        {
            "Light" => ElementTheme.Light,
            "Dark" => ElementTheme.Dark,
            _ => ElementTheme.Default,
        };
        if (XamlRoot?.Content is FrameworkElement root)
            root.RequestedTheme = requestedTheme;
    }

    private void AutoReinstallToggle_Toggled(object sender, RoutedEventArgs e)
    {
        if (!_isLoaded) return;
        ViewModel.AutoReinstall = AutoReinstallToggle.IsOn;
    }

    private void AutoUpdateCheckToggle_Toggled(object sender, RoutedEventArgs e)
    {
        if (!_isLoaded) return;
        ViewModel.AutoCheckVersion = AutoUpdateCheckToggle.IsOn;
    }
}
