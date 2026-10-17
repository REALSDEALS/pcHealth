using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class TraceroutePage : Page
{
    public TracerouteViewModel ViewModel { get; } = App.Services.GetRequiredService<TracerouteViewModel>();

    private int _renderedHopCount;
    private static readonly Microsoft.UI.Xaml.Media.FontFamily MonoFont = new("Cascadia Code, Consolas, Courier New");

    public TraceroutePage()
    {
        InitializeComponent();
        ViewModel.PropertyChanged += OnViewModelPropertyChanged;
    }

    private void OnViewModelPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName != nameof(ViewModel.Hops)) return;

        var hops = ViewModel.Hops;

        // New run: ViewModel resets Hops to []. Clear rows and counter.
        if (hops.Count < _renderedHopCount)
        {
            HopRows.Children.Clear();
            ResultsCard.Visibility = Visibility.Collapsed;
            _renderedHopCount = 0;
        }

        // Append any newly added hops (they arrive one at a time during the trace).
        for (int i = _renderedHopCount; i < hops.Count; i++)
            AddHopRow(hops[i]);

        if (hops.Count > 0) ResultsCard.Visibility = Visibility.Visible;
        _renderedHopCount = hops.Count;
    }

    private void AddHopRow(TracerouteViewModel.HopResult hop)
    {
        var row = new Grid { ColumnSpacing = 16 };
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(30) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(160) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var hopNum = new TextBlock
        {
            Text = $"{hop.Hop,2}",
            FontFamily = MonoFont,
            FontSize = 13,
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
            IsTextSelectionEnabled = true,
        };
        var addrText = new TextBlock
        {
            Text = hop.Address,
            FontFamily = MonoFont,
            FontSize = 13,
            IsTextSelectionEnabled = true,
            Foreground = hop.Reached
                ? new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(0xFF, 0x0F, 0x9D, 0x58))
                : (Brush)Application.Current.Resources["TextFillColorPrimaryBrush"],
        };
        var latText = new TextBlock
        {
            Text = hop.Latency,
            FontFamily = MonoFont,
            FontSize = 13,
            IsTextSelectionEnabled = true,
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
        };

        Grid.SetColumn(addrText, 1);
        Grid.SetColumn(latText, 2);
        row.Children.Add(hopNum);
        row.Children.Add(addrText);
        row.Children.Add(latText);
        HopRows.Children.Add(row);
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.RunCancelCommand.Execute(null);
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
