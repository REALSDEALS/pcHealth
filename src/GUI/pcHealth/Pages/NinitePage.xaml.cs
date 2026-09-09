using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class NinitePage : Page
{
    public NiniteViewModel ViewModel { get; } = App.Services.GetRequiredService<NiniteViewModel>();

    public NinitePage()
    {
        InitializeComponent();
        ViewModel.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(ViewModel.ErrorMessage))
            {
                ErrorBar.Message = ViewModel.ErrorMessage;
                ErrorBar.IsOpen = !string.IsNullOrEmpty(ViewModel.ErrorMessage);
            }
        };
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
