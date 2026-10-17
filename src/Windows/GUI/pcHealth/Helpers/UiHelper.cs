using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace pcHealth.Helpers;

/// <summary>
/// Shared UI building blocks reused across multiple pages.
/// Centralising these patterns means a single fix here propagates everywhere.
/// </summary>
internal static class UiHelper
{
    /// <summary>
    /// Returns a thread-safe "append line" callback for a scrolling output TextBlock.
    /// Each call appends one line and scrolls the containing ScrollViewer to the bottom.
    /// Safe to call from any thread. Dispatches to the UI thread internally.
    /// </summary>
    internal static Action<string> CreateAppendHandler(
        TextBlock output, ScrollViewer scroller, DispatcherQueue dispatcher)
    {
        return line => dispatcher.TryEnqueue(() =>
        {
            output.Text += line + "\n";
            scroller.ScrollToVerticalOffset(double.MaxValue);
        });
    }

    /// <summary>
    /// Adds a two-column label/value row to <paramref name="panel"/>.
    /// The label column is fixed-width; the value column stretches to fill remaining space.
    /// </summary>
    /// <param name="labelWidth">Fixed width of the label column in pixels (default 160).</param>
    internal static void AddLabelValueRow(
        StackPanel panel, string label, string value, int labelWidth = 160)
    {
        var grid = new Grid { ColumnSpacing = 12, Margin = new Thickness(0, 1, 0, 1) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(labelWidth) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        grid.Children.Add(new TextBlock
        {
            Text = label,
            Style = (Style)Application.Current.Resources["CaptionTextBlockStyle"],
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
            VerticalAlignment = VerticalAlignment.Top,
        });

        var val = new TextBlock
        {
            Text = value,
            IsTextSelectionEnabled = true,
            TextWrapping = TextWrapping.Wrap,
        };
        Grid.SetColumn(val, 1);
        grid.Children.Add(val);
        panel.Children.Add(grid);
    }
}
