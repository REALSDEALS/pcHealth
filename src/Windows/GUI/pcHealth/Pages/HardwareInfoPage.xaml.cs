using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class HardwareInfoPage : Page
{
    public HardwareInfoViewModel ViewModel { get; } = App.Services.GetRequiredService<HardwareInfoViewModel>();

    public HardwareInfoPage()
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
        PopulateCard(CpuRows, ViewModel.CpuRows, CpuCard);
        if (ViewModel.GpuRows.Count > 0) PopulateCard(GpuRows, ViewModel.GpuRows, GpuCard);
        PopulateCard(RamRows, ViewModel.RamRows, RamCard);
        PopulateCard(StorageRows, ViewModel.StorageRows, StorageCard);
        PopulateCard(ChipsetRows, ViewModel.ChipsetRows, ChipsetCard);
        CopyBtn.IsEnabled = true;
    }

    private void PopulateCard(StackPanel panel, List<(string Label, string Value)> rows, Border card)
    {
        foreach (var (label, value) in rows)
            AddRow(panel, label, value);
        card.Visibility = Visibility.Visible;
    }

    private void AddRow(StackPanel panel, string label, string value)
    {
        if (string.IsNullOrEmpty(label) && string.IsNullOrEmpty(value))
        {
            panel.Children.Add(new Border { Height = 8 });
            return;
        }
        var grid = new Grid { ColumnSpacing = 12, Margin = new Thickness(0, 1, 0, 1) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(180) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        var lbl = new TextBlock
        {
            Text = label,
            Style = (Style)Application.Current.Resources["CaptionTextBlockStyle"],
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
            VerticalAlignment = VerticalAlignment.Top,
        };
        var val = new TextBlock { Text = value, IsTextSelectionEnabled = true, TextWrapping = TextWrapping.Wrap };
        Grid.SetColumn(val, 1);
        grid.Children.Add(lbl);
        grid.Children.Add(val);
        panel.Children.Add(grid);
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
