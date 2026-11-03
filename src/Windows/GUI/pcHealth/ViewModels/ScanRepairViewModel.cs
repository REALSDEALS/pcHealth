using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using pcHealth.Services;
using System.Text;

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
            // Exit codes are kept per step: "Done." used to show even when
            // every step had failed.
            var codes = new List<(string Step, int Code)>();

            Append("=== Step 1/5: SFC (initial scan) ===");
            codes.Add(("SFC", await _runner.RunAsync(sfc, "/scannow", Append, ct, outputEncoding: Encoding.Unicode)));

            Append("\n=== Step 2/5: DISM CheckHealth ===");
            codes.Add(("CheckHealth", await _runner.RunAsync(dism, "/Online /Cleanup-Image /CheckHealth", Append, ct)));

            Append("\n=== Step 3/5: DISM ScanHealth ===");
            codes.Add(("ScanHealth", await _runner.RunAsync(dism, "/Online /Cleanup-Image /ScanHealth", Append, ct)));

            Append("\n=== Step 4/5: DISM RestoreHealth ===");
            codes.Add(("RestoreHealth", await _runner.RunAsync(dism, "/Online /Cleanup-Image /RestoreHealth", Append, ct)));

            Append("\n=== Step 5/5: SFC (final pass) ===");
            codes.Add(("SFC final", await _runner.RunAsync(sfc, "/scannow", Append, ct, outputEncoding: Encoding.Unicode)));

            var cbsLog = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "Logs", "CBS", "CBS.log");
            Append($"\n=== Complete. Full log: {cbsLog} ===");
            Append("Exit codes: " + string.Join(", ", codes.Select(c => $"{c.Step} {c.Code}")));

            var failed = codes.Where(c => c.Code != 0).Select(c => c.Step).ToList();
            Status = failed.Count == 0
                ? "Done. Every step reported success."
                : $"Done, but these steps reported a problem: {string.Join(", ", failed)}. See Details.";
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
