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

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
