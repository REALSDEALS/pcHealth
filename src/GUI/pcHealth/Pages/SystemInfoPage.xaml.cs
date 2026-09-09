using pcHealth.Helpers;
using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class SystemInfoPage : Page
{
    public SystemInfoViewModel ViewModel { get; } = App.Services.GetRequiredService<SystemInfoViewModel>();

    public SystemInfoPage()
    {
        InitializeComponent();
        Loaded += async (_, _) =>
        {
            await ViewModel.LoadCommand.ExecuteAsync(null);
            if (!string.IsNullOrEmpty(ViewModel.ErrorMessage))
            {
                ErrorBar.Message = ViewModel.ErrorMessage;
                ErrorBar.IsOpen = true;
                return;
            }
            PopulateUi();
        };
    }

    private void PopulateUi()
    {
        LoadingPanel.Visibility = Visibility.Collapsed;
        PopulateCard(OsRows, ViewModel.OsRows, OsCard);
        PopulateCard(MachineRows, ViewModel.MachineRows, MachineCard);
        PopulateCard(FirmwareRows, ViewModel.FirmwareRows, FirmwareCard);
        PopulateCard(HardwareRows, ViewModel.HardwareRows, HardwareCard);
        CopyBtn.IsEnabled = true;
    }

    private static void PopulateCard(StackPanel panel, List<(string Label, string Value)> rows, Border card)
    {
        foreach (var (label, value) in rows)
            UiHelper.AddLabelValueRow(panel, label, value, labelWidth: 180);
        card.Visibility = Visibility.Visible;
    }

    private void CopyBtn_Click(object sender, RoutedEventArgs e)
    {
        var pkg = new DataPackage();
        pkg.SetText(ViewModel.CopyText);
        Clipboard.SetContent(pkg);
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
