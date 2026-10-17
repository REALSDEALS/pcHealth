using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class DiskCleanupPage : Page
{
    public DiskCleanupViewModel ViewModel { get; } = App.Services.GetRequiredService<DiskCleanupViewModel>();

    public DiskCleanupPage() => InitializeComponent();

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
