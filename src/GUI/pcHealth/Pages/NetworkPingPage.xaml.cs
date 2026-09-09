using pcHealth.Helpers;
using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class NetworkPingPage : Page
{
    public NetworkPingViewModel ViewModel { get; } = App.Services.GetRequiredService<NetworkPingViewModel>();

    public NetworkPingPage()
    {
        InitializeComponent();
        ViewModel.PropertyChanged += OnViewModelPropertyChanged;
    }

    private void OnViewModelPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(ViewModel.HasResults) && ViewModel.HasResults)
            PopulateResults();
        else if (e.PropertyName == nameof(ViewModel.IsRunning) && ViewModel.IsRunning)
            ClearResults();
    }

    private void ClearResults()
    {
        PingResultRows.Children.Clear();
        SummaryRows.Children.Clear();
        ResultsCard.Visibility = Visibility.Collapsed;
        SummaryCard.Visibility = Visibility.Collapsed;
    }

    private void PopulateResults()
    {
        PingResultRows.Children.Clear();
        SummaryRows.Children.Clear();

        foreach (var r in ViewModel.Results)
        {
            var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12 };
            row.Children.Add(new FontIcon
            {
                Glyph = r.Success ? "" : "",
                FontSize = 14,
                VerticalAlignment = VerticalAlignment.Center,
                Foreground = r.Success
                    ? new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(0xFF, 0x0F, 0x9D, 0x58))
                    : (Brush)Application.Current.Resources["SystemFillColorCriticalBrush"],
            });
            row.Children.Add(new TextBlock
            {
                Text = r.Success ? $"Reply from {r.Address}: {r.Latency} ms" : $"Timeout / {r.Status}",
                VerticalAlignment = VerticalAlignment.Center,
            });
            PingResultRows.Children.Add(row);
        }
        ResultsCard.Visibility = Visibility.Visible;

        foreach (var (label, value) in ViewModel.Summary)
            UiHelper.AddLabelValueRow(SummaryRows, label, value);
        SummaryCard.Visibility = Visibility.Visible;
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.RunCancelCommand.Execute(null);
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
