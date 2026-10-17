using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using System.Diagnostics;
using System.Net.Http;

namespace pcHealth.ViewModels;

public partial class NiniteViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();
    private static readonly HttpClient Http = new();
    private const string NiniteUrl = "https://ninite.com/7zip-chrome-edge-vlc/ninite.exe";

    [ObservableProperty] public partial bool IsDownloading { get; set; }
    [ObservableProperty] public partial string Status { get; set; } = "";
    [ObservableProperty] public partial string ErrorMessage { get; set; } = "";

    [RelayCommand(CanExecute = nameof(CanDownload))]
    public async Task DownloadAsync()
    {
        IsDownloading = true;
        Status = "Downloading...";
        ErrorMessage = "";
        try
        {
            var dest = Path.Combine(Path.GetTempPath(), "pcHealth-ninite.exe");
            using (var response = await Http.GetStreamAsync(NiniteUrl))
            using (var file = File.OpenWrite(dest))
                await response.CopyToAsync(file);

            Status = "Launching installer...";
            Process.Start(new ProcessStartInfo(dest) { UseShellExecute = true });
            Status = "Installer launched.";
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Ninite download failed");
            Status = "";
            ErrorMessage = ex.Message;
        }
        finally
        {
            IsDownloading = false;
        }
    }

    private bool CanDownload() => !IsDownloading;
}
