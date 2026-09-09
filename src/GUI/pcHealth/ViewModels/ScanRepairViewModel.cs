using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class ScanRepairViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();
    private readonly IProcessRunner _runner;

    [ObservableProperty] public partial string Output { get; set; } = "";
    [ObservableProperty] public partial string Status { get; set; } = "";
    [ObservableProperty] public partial bool IsRunning { get; set; }

    public ScanRepairViewModel(IProcessRunner runner) => _runner = runner;

    [RelayCommand(CanExecute = nameof(CanRun), IncludeCancelCommand = true)]
    public async Task RunAsync(CancellationToken ct)
    {
        IsRunning = true;
        Output = "";
        Status = "Running... this may take several minutes.";

        var dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        void Append(string line) => dispatcher.TryEnqueue(() => Output += line + "\n");

        var sfc = Path.Combine(Environment.SystemDirectory, "sfc.exe");
        var dism = Path.Combine(Environment.SystemDirectory, "Dism.exe");

        try
        {
            Append("=== Step 1/5: SFC (initial scan) ===");
            await _runner.RunAsync(sfc, "/scannow", Append, ct);

            Append("\n=== Step 2/5: DISM CheckHealth ===");
            await _runner.RunAsync(dism, "/Online /Cleanup-Image /CheckHealth", Append, ct);

            Append("\n=== Step 3/5: DISM ScanHealth ===");
            await _runner.RunAsync(dism, "/Online /Cleanup-Image /ScanHealth", Append, ct);

            Append("\n=== Step 4/5: DISM RestoreHealth ===");
            await _runner.RunAsync(dism, "/Online /Cleanup-Image /RestoreHealth", Append, ct);

            Append("\n=== Step 5/5: SFC (final pass) ===");
            await _runner.RunAsync(sfc, "/scannow", Append, ct);

            Append($"\n=== Complete. Full log: {Environment.GetEnvironmentVariable("SystemRoot")}\\Logs\\CBS\\CBS.log ===");
            Status = "Done.";
        }
        catch (OperationCanceledException)
        {
            Output += "\n[Cancelled]";
            Status = "Cancelled.";
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Scan+Repair failed");
            Output += $"\n[Error] {ex.Message}";
            Status = "Error. See output.";
        }
        finally
        {
            IsRunning = false;
        }
    }

    private bool CanRun() => !IsRunning;
}
