using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class WingetRepairPage : Page
{
    public WingetRepairViewModel ViewModel { get; } = App.Services.GetRequiredService<WingetRepairViewModel>();

    public WingetRepairPage()
    {
        InitializeComponent();
        ViewModel.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(ViewModel.Output))
                OutputScroller.DispatcherQueue.TryEnqueue(() =>
                    OutputScroller.ChangeView(null, double.MaxValue, null, true));
        };
    }

    // Back is not the only way out: the sidebar navigates away too, and
    // the work kept running on a page nobody could see any more.
    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        ViewModel.RunCancelCommand.Execute(null);
        base.OnNavigatedFrom(e);
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.RunCancelCommand.Execute(null);
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
