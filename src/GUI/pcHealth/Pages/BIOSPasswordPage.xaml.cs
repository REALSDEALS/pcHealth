using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class BIOSPasswordPage : Page
{
    public BIOSPasswordViewModel ViewModel { get; } = App.Services.GetRequiredService<BIOSPasswordViewModel>();

    public BIOSPasswordPage() => InitializeComponent();

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
