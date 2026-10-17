using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class BootRepairViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();
    private readonly IProcessRunner _runner;

    [ObservableProperty] public partial string Output { get; set; } = "";
    [ObservableProperty] public partial string Status { get; set; } = "";
    [ObservableProperty] public partial bool IsRunning { get; set; }

    public BootRepairViewModel(IProcessRunner runner) => _runner = runner;

    [RelayCommand(CanExecute = nameof(CanRun), IncludeCancelCommand = true)]
    public async Task RunAsync(CancellationToken ct)
    {
        IsRunning = true;
        Output = "";
        Status = "Running boot repair…";

        var dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        void Append(string line) => dispatcher.TryEnqueue(() => Output += line + "\n");

        try
        {
            var bootrec = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "bootrec.exe");

            var failed = new List<string>();
            foreach (var step in new[] { "/fixmbr", "/fixboot", "/scanos", "/rebuildbcd" })
            {
                Append($"\n[>>] bootrec {step}");
                if (await _runner.RunAsync(bootrec, step, Append, ct) != 0)
                    failed.Add(step);
            }

            if (failed.Count == 0)
            {
                Append("\n[OK] Boot repair complete. Reboot the system to verify.");
                Status = "Done. Reboot required.";
            }
            else
            {
                // /fixboot returns "Access is denied" on every EFI system, so a
                // failure here is expected on modern hardware rather than alarming.
                Append($"\n[!!] These steps failed: {string.Join(", ", failed)}.");
                Append("     On a UEFI/GPT system that is normal for /fixmbr and /fixboot.");
                Status = "Completed with errors.";
            }
        }
        catch (OperationCanceledException)
        {
            Output += "\n[Cancelled]";
            Status = "Cancelled.";
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Boot repair failed");
            Output += $"\n[Error] {ex.Message}";
            Status = "Error.";
        }
        finally
        {
            IsRunning = false;
        }
    }

    private bool CanRun() => !IsRunning;
}
