using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class WindowsUpdatePage : Page
{
    public WindowsUpdateViewModel ViewModel { get; } = App.Services.GetRequiredService<WindowsUpdateViewModel>();

    public WindowsUpdatePage() => InitializeComponent();

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
