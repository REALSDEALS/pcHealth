using pcHealth.Helpers;
using pcHealth.Services;
using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class ProgramsPage : Page
{
    public ProgramsViewModel ViewModel { get; } = App.Services.GetRequiredService<ProgramsViewModel>();

    // AutoReinstall is a user preference checked at install-time; read it directly from settings.
    private readonly IAppSettings _settings = App.Services.GetRequiredService<IAppSettings>();

    public ProgramsPage()
    {
        InitializeComponent();
        var cvs = new Microsoft.UI.Xaml.Data.CollectionViewSource
        {
            IsSourceGrouped = true,
            Source = ViewModel.GroupedPrograms,
        };
        ProgramsList.ItemsSource = cvs.View;
    }

    protected override void OnNavigatedTo(Microsoft.UI.Xaml.Navigation.NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        ViewModel.CheckInstalledCommand.Execute(null);
    }

    private async void InstallBtn_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button btn || btn.Tag is not ProgramItem item) return;

        if (item.IsInstalled)
        {
            if (_settings.GetBool("AutoReinstall", fallback: false))
            {
                try { await ViewModel.ForceInstallAsync(item); }
                catch (Exception ex) { _ = DialogHelper.ShowErrorAsync(XamlRoot, "Could not launch installer", ex.Message); }
                return;
            }

            var dialog = new ContentDialog
            {
                Title = item.Name,
                Content = $"{item.Name} is already installed.",
                PrimaryButtonText = "Open",
                SecondaryButtonText = "Update",
                CloseButtonText = "Cancel",
                DefaultButton = ContentDialogButton.Primary,
                XamlRoot = XamlRoot,
            };

            var result = await dialog.ShowAsync();

            try
            {
                if (result == ContentDialogResult.Primary)
                    await ViewModel.InstallOrOpenAsync(item);
                else if (result == ContentDialogResult.Secondary)
                    await ViewModel.UpdateAsync(item);
            }
            catch (Exception ex)
            {
                _ = DialogHelper.ShowErrorAsync(
                    XamlRoot,
                    result == ContentDialogResult.Primary ? "Could not open program" : "Could not launch updater",
                    ex.Message);
            }
            return;
        }

        try { await ViewModel.InstallOrOpenAsync(item); }
        catch (Exception ex) { _ = DialogHelper.ShowErrorAsync(XamlRoot, "Could not launch installer", ex.Message); }
    }
}
