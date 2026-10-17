using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class NetworkContinuousPage : Page
{
    public NetworkContinuousViewModel ViewModel { get; } = App.Services.GetRequiredService<NetworkContinuousViewModel>();

    public NetworkContinuousPage()
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
        ViewModel.StopCommand.Execute(null);
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
