using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class ScanRepairPage : Page
{
    public ScanRepairViewModel ViewModel { get; } = App.Services.GetRequiredService<ScanRepairViewModel>();

    public ScanRepairPage()
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
