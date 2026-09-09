using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class ToolsPage : Page
{
    public ToolsViewModel ViewModel { get; } = App.Services.GetRequiredService<ToolsViewModel>();

    public ToolsPage()
    {
        InitializeComponent();
        var cvs = new Microsoft.UI.Xaml.Data.CollectionViewSource
        {
            IsSourceGrouped = true,
            Source = ViewModel.GroupedTools,
        };
        ToolsGrid.ItemsSource = cvs.View;
    }

    private void ToolsGrid_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is not ToolItem item) return;
        Frame.Navigate(item.PageType);
    }
}
