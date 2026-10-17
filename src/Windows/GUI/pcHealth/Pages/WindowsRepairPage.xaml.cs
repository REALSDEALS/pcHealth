using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class WindowsRepairPage : Page
{
    public WindowsRepairViewModel ViewModel { get; } = App.Services.GetRequiredService<WindowsRepairViewModel>();

    public WindowsRepairPage()
    {
        InitializeComponent();
        // The confirmation dialog needs a XamlRoot, which only exists once the
        // page is in the tree.
        Loaded += (_, _) => ViewModel.XamlRoot = XamlRoot;
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
