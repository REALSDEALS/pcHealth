using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class CBSLogPage : Page
{
    public CBSLogViewModel ViewModel { get; } = App.Services.GetRequiredService<CBSLogViewModel>();

    public CBSLogPage()
    {
        InitializeComponent();
        Loaded += async (_, _) =>
        {
            await ViewModel.LoadCommand.ExecuteAsync(null);
            LogScroller.ChangeView(null, double.MaxValue, null, true);
        };
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
