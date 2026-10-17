using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class HPUpdatePage : Page
{
    public HPUpdateViewModel ViewModel { get; } = App.Services.GetRequiredService<HPUpdateViewModel>();

    public HPUpdatePage() => InitializeComponent();

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.InstallCancelCommand.Execute(null);
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
