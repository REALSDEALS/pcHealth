using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class BootRepairPage : Page
{
    public BootRepairViewModel ViewModel { get; } = App.Services.GetRequiredService<BootRepairViewModel>();

    public BootRepairPage()
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
            Title = "Repair Boot Record",
            Content = "This will run bootrec /fixmbr, /fixboot, /scanos and /rebuildbcd.\n\n" +
                      "This modifies boot-critical files. Incorrect use can make the system unbootable.",
            PrimaryButtonText = "Proceed",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = XamlRoot,
        };
        if (await confirm.ShowAsync() != ContentDialogResult.Primary) return;

        await ViewModel.RunCommand.ExecuteAsync(null);
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.RunCancelCommand.Execute(null);
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
