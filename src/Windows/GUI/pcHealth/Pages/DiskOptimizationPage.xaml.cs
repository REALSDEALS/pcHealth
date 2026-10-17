using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class DiskOptimizationPage : Page
{
    public DiskOptimizationViewModel ViewModel { get; } = App.Services.GetRequiredService<DiskOptimizationViewModel>();

    public DiskOptimizationPage() => InitializeComponent();

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
