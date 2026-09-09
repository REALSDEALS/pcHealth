using pcHealth.Helpers;
using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class BatteryReportPage : Page
{
    public BatteryReportViewModel ViewModel { get; } = App.Services.GetRequiredService<BatteryReportViewModel>();

    public BatteryReportPage()
    {
        InitializeComponent();
        Loaded += async (_, _) =>
        {
            await ViewModel.LoadCommand.ExecuteAsync(null);
            OnLoadComplete();
        };
    }

    private void OnLoadComplete()
    {
        LoadingPanel.Visibility = Visibility.Collapsed;

        if (!string.IsNullOrEmpty(ViewModel.ErrorMessage))
        {
            ErrorBar.Message = ViewModel.ErrorMessage;
            ErrorBar.IsOpen = true;
            return;
        }

        if (!ViewModel.HasBattery)
        {
            NoBatteryBar.IsOpen = true;
            return;
        }

        foreach (var (label, value) in ViewModel.Rows)
            AddRow(StatusRows, label, value);

        StatusCard.Visibility = Visibility.Visible;
        ReportCard.Visibility = Visibility.Visible;
    }

    private void AddRow(StackPanel panel, string label, string value)
    {
        var grid = new Grid { ColumnSpacing = 12, Margin = new Thickness(0, 1, 0, 1) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(180) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.Children.Add(new TextBlock
        {
            Text = label,
            Style = (Style)Application.Current.Resources["CaptionTextBlockStyle"],
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
            VerticalAlignment = VerticalAlignment.Top,
        });
        var val = new TextBlock { Text = value, IsTextSelectionEnabled = true };
        Grid.SetColumn(val, 1);
        grid.Children.Add(val);
        panel.Children.Add(grid);
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
