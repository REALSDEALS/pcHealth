using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class OpenBatteryReportPage : Page
{
    public OpenBatteryReportViewModel ViewModel { get; } = App.Services.GetRequiredService<OpenBatteryReportViewModel>();

    public OpenBatteryReportPage()
    {
        InitializeComponent();
        Loaded += (_, _) =>
        {
            ViewModel.LoadCommand.Execute(null);
            NotFoundBar.IsOpen = !ViewModel.ReportExists;
        };
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
