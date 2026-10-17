using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class SettingsViewModel : ObservableObject
{
    private readonly IAppSettings _settings;

    [ObservableProperty] public partial string Theme { get; set; } = "Default";
    [ObservableProperty] public partial bool AutoReinstall { get; set; }
    [ObservableProperty] public partial bool AutoCheckVersion { get; set; }

    public SettingsViewModel(IAppSettings settings)
    {
        _settings = settings;
        // Assign via property setters; OnXxxChanged writes back the same value (harmless).
        Theme = _settings.Get("AppTheme", "Default");
        AutoReinstall = _settings.GetBool("AutoReinstall", fallback: false);
        AutoCheckVersion = _settings.GetBool("AutoCheckVersion", fallback: true);
    }

    partial void OnThemeChanged(string value) =>
        _settings.Set("AppTheme", value);

    partial void OnAutoReinstallChanged(bool value) =>
        _settings.Set("AutoReinstall", value ? "true" : "false");

    partial void OnAutoCheckVersionChanged(bool value) =>
        _settings.Set("AutoCheckVersion", value ? "true" : "false");
}
