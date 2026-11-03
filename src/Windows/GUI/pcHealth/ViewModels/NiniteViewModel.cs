using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using pcHealth.Services;
using System.Diagnostics;
using System.Net.Http;
using System.Text;

namespace pcHealth.ViewModels;

public partial class NiniteViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();
    private static readonly HttpClient Http = new();
    private const string NiniteUrl = "https://ninite.com/7zip-chrome-edge-vlc/ninite.exe";
    private const string NinitePublisher = "O=Secure By Design Inc.";
    private readonly IProcessRunner _runner;

    [ObservableProperty] public partial bool IsDownloading { get; set; }
    [ObservableProperty] public partial string Status { get; set; } = "";
    [ObservableProperty] public partial string ErrorMessage { get; set; } = "";

    public NiniteViewModel(IProcessRunner runner) => _runner = runner;

    [RelayCommand(CanExecute = nameof(CanDownload))]
    public async Task DownloadAsync()
    {
        IsDownloading = true;
        Status = "Downloading...";
        ErrorMessage = "";
        try
        {
            var dest = Path.Combine(Path.GetTempPath(), "pcHealth-ninite.exe");
            // File.Create truncates; File.OpenWrite left the tail of an older,
            // longer download behind and produced a corrupt executable.
            using (var response = await Http.GetStreamAsync(NiniteUrl))
            using (var file = File.Create(dest))
                await response.CopyToAsync(file);

            Status = "Checking signature...";
            var (signature, subject) = await GetSignatureAsync(dest);
            // The installer inherits this app's administrator rights, so only
            // start it when it is unmodified and signed by Ninite's publisher.
            if (signature != "Valid" || !subject.Contains(NinitePublisher, StringComparison.Ordinal))
            {
                Log.Warn("Ninite download rejected: signature {Signature}, subject {Subject}", signature, subject);
                Status = "";
                ErrorMessage = $"The download is not signed by Ninite (signature: {signature}). It was not started.";
                return;
            }

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

    // .NET has no Authenticode check built in; Windows PowerShell 5.1 is on
    // every supported Windows and asks WinVerifyTrust for us.
    private async Task<(string Status, string Subject)> GetSignatureAsync(string path)
    {
        var host = Path.Combine(Environment.SystemDirectory, "WindowsPowerShell", "v1.0", "powershell.exe");
        // With stderr redirected, powershell.exe writes its progress records
        // there as a "#< CLIXML" block; silence them and read only the
        // marked answer line.
        var script = "$ProgressPreference = 'SilentlyContinue'; " +
                     $"$s = Get-AuthenticodeSignature -LiteralPath '{path.Replace("'", "''")}'; " +
                     "\"SIG|$($s.Status)|$($s.SignerCertificate.Subject)\"";
        var encoded = Convert.ToBase64String(Encoding.Unicode.GetBytes(script));

        string? answer = null;
        await _runner.RunAsync(host, $"-NoProfile -NonInteractive -EncodedCommand {encoded}",
            line => { if (line.StartsWith("SIG|", StringComparison.Ordinal)) answer = line; },
            timeout: TimeSpan.FromSeconds(30));

        var parts = answer?.Split('|', 3);
        return parts is { Length: 3 } ? (parts[1], parts[2]) : ("Unknown", "");
    }
}
