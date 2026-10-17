using Microsoft.UI.Xaml.Media.Imaging;
using pcHealth.ViewModels;

namespace pcHealth.Pages;

public sealed partial class InfoPage : Page
{
    public InfoViewModel ViewModel { get; } = App.Services.GetRequiredService<InfoViewModel>();

    public InfoPage()
    {
        InitializeComponent();
        VersionText.Text = ViewModel.Version;

        // WinUI 3 SvgImageSource doesn't support SVG <mask>, so use the pre-rendered PNG.
        var pngPath = Path.Combine(AppContext.BaseDirectory, "Assets", "pcHealth.png");
        if (File.Exists(pngPath))
            AppLogo.Source = new BitmapImage(new Uri(pngPath));
    }
}
