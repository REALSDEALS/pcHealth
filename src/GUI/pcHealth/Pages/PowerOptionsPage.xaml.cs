using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class PowerOptionsPage : Page
{
    public PowerOptionsViewModel ViewModel { get; } = App.Services.GetRequiredService<PowerOptionsViewModel>();

    public PowerOptionsPage() => InitializeComponent();

    private async void LogOffBtn_Click(object sender, RoutedEventArgs e)
    {
        if (!await ConfirmAsync("Log Off", "Sign out the current Windows session?")) return;
        ViewModel.LogOffCommand.Execute(null);
    }

    private async void RestartBtn_Click(object sender, RoutedEventArgs e)
    {
        if (!await ConfirmAsync("Restart", "Restart the PC immediately?")) return;
        ViewModel.RestartCommand.Execute(null);
    }

    private async void ShutdownBtn_Click(object sender, RoutedEventArgs e)
    {
        if (!await ConfirmAsync("Shutdown", "Shut down the PC immediately?")) return;
        ViewModel.ShutdownCommand.Execute(null);
    }

    // ContentDialog needs XamlRoot, so confirmation stays in code-behind.
    private async Task<bool> ConfirmAsync(string title, string message)
    {
        var dialog = new ContentDialog
        {
            Title = title,
            Content = message,
            PrimaryButtonText = title,
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = XamlRoot,
        };
        return await dialog.ShowAsync() == ContentDialogResult.Primary;
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
