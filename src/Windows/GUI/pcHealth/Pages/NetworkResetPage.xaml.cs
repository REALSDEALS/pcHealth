using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class NetworkResetPage : Page
{
    public NetworkResetViewModel ViewModel { get; } = App.Services.GetRequiredService<NetworkResetViewModel>();

    public NetworkResetPage()
    {
        InitializeComponent();
        ViewModel.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(ViewModel.Output))
                OutputScroller.DispatcherQueue.TryEnqueue(() =>
                    OutputScroller.ChangeView(null, double.MaxValue, null, true));
        };
    }

    // ContentDialog stays here: it requires XamlRoot which is a UI concern.
    private async void RunBtn_Click(object sender, RoutedEventArgs e)
    {
        if (!ViewModel.RunCommand.CanExecute(null)) return;

        var confirm = new ContentDialog
        {
            Title = "Reset Network Stack",
            Content = "The connection drops for a moment: remote sessions (TeamViewer, AnyDesk, RDP) will disconnect.\n\n" +
                      "The IP reset can remove static IP and DNS settings. Note them down first.",
            PrimaryButtonText = "Reset",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = XamlRoot,
        };
        if (await confirm.ShowAsync() != ContentDialogResult.Primary) return;

        await ViewModel.RunCommand.ExecuteAsync(null);
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
