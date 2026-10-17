using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class SystemUpdatePage : Page
{
    public SystemUpdateViewModel ViewModel { get; } = App.Services.GetRequiredService<SystemUpdateViewModel>();

    public SystemUpdatePage() => InitializeComponent();

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.RunCancelCommand.Execute(null);
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
