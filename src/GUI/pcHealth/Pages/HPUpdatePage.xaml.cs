using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class HPUpdatePage : Page
{
    public HPUpdateViewModel ViewModel { get; } = App.Services.GetRequiredService<HPUpdateViewModel>();

    public HPUpdatePage()
    {
        InitializeComponent();
        ViewModel.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(ViewModel.Output))
                OutputScroller.DispatcherQueue.TryEnqueue(() =>
                    OutputScroller.ChangeView(null, double.MaxValue, null, true));
        };
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.InstallCancelCommand.Execute(null);
        if (Frame.CanGoBack) Frame.GoBack();
    }
}
