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

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.RunCancelCommand.Execute(null);
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
