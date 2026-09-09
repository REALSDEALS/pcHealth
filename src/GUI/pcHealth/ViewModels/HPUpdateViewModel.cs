using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class HPUpdateViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();
    private readonly IProcessRunner _runner;

    [ObservableProperty] public partial string Output { get; set; } = "";
    [ObservableProperty] public partial string Status { get; set; } = "";
    [ObservableProperty] public partial bool IsRunning { get; set; }

    public HPUpdateViewModel(IProcessRunner runner) => _runner = runner;

    [RelayCommand(CanExecute = nameof(CanInstall), IncludeCancelCommand = true)]
    public async Task InstallAsync(CancellationToken ct)
    {
        IsRunning = true;
        Output = "";
        Status = "Installing…";

        var dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        void Append(string line) => dispatcher.TryEnqueue(() => Output += line + "\n");

        try
        {
            await _runner.RunAsync("winget.exe",
                "install --id HP.ImageAssistant --accept-source-agreements --accept-package-agreements",
                Append, ct);
            Status = "Done. Launch HP Image Assistant to update drivers.";
        }
        catch (OperationCanceledException)
        {
            Status = "Cancelled.";
        }
        catch (Exception ex)
        {
            Log.Error(ex, "HP Image Assistant install failed");
            Status = $"Error: {ex.Message}";
        }
        finally
        {
            IsRunning = false;
        }
    }

    private bool CanInstall() => !IsRunning;
}
