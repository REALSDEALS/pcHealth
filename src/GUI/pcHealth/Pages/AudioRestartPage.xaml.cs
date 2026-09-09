using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class AudioRestartPage : Page
{
    public AudioRestartViewModel ViewModel { get; } = App.Services.GetRequiredService<AudioRestartViewModel>();

    public AudioRestartPage()
    {
        InitializeComponent();
        Loaded += async (_, _) => await ViewModel.LoadStatusCommand.ExecuteAsync(null);
        ViewModel.PropertyChanged += OnViewModelPropertyChanged;
    }

    private void OnViewModelPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        switch (e.PropertyName)
        {
            case nameof(ViewModel.AebRunning):
                SetStatus(AebIcon, AebStatus, ViewModel.AebRunning);
                break;
            case nameof(ViewModel.AudioRunning):
                SetStatus(AudioIcon, AudioStatus, ViewModel.AudioRunning);
                break;
            case nameof(ViewModel.Succeeded) when ViewModel.Succeeded:
                ResultBar.Severity = InfoBarSeverity.Success;
                ResultBar.Title = "Audio services restarted. Test your audio now.";
                ResultBar.Message = "";
                ResultBar.IsOpen = true;
                break;
            case nameof(ViewModel.ErrorMessage) when !string.IsNullOrEmpty(ViewModel.ErrorMessage):
                ResultBar.Severity = InfoBarSeverity.Error;
                ResultBar.Title = "Failed to restart audio services";
                ResultBar.Message = ViewModel.ErrorMessage;
                ResultBar.IsOpen = true;
                break;
        }
    }

    private void SetStatus(FontIcon icon, TextBlock label, bool running)
    {
        label.Text = running ? "Running" : "Stopped";
        icon.Glyph = running ? "" : "";
        icon.Foreground = running
            ? new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(0xFF, 0x0F, 0x9D, 0x58))
            : (Brush)Application.Current.Resources["TextFillColorTertiaryBrush"];
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
