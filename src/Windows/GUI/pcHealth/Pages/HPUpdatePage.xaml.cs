using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class HPUpdatePage : Page
{
    public HPUpdateViewModel ViewModel { get; } = App.Services.GetRequiredService<HPUpdateViewModel>();

    public HPUpdatePage() => InitializeComponent();

    // Back is not the only way out: the sidebar navigates away too, and
    // the work kept running on a page nobody could see any more.
    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        ViewModel.InstallCancelCommand.Execute(null);
        base.OnNavigatedFrom(e);
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.InstallCancelCommand.Execute(null);
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
