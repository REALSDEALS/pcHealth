using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class WingetRepairViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();
    private readonly IProcessRunner _runner;

    [ObservableProperty] public partial string Output { get; set; } = "";
    [ObservableProperty] public partial string Status { get; set; } = "";
    [ObservableProperty] public partial bool IsRunning { get; set; }

    public WingetRepairViewModel(IProcessRunner runner) => _runner = runner;

    [RelayCommand(CanExecute = nameof(CanRun), IncludeCancelCommand = true)]
    public async Task RunAsync(CancellationToken ct)
    {
        IsRunning = true;
        Output = "";
        Status = "Repairing winget…";

        var dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        void Append(string line) => dispatcher.TryEnqueue(() => Output += line + "\n");

        try
        {
            Append("[>>] Installing winget-install script from PSGallery…");
            int installExit = await _runner.RunAsync("pwsh.exe",
                "-NoProfile -ExecutionPolicy Bypass -Command \"Install-Script -Name winget-install -Force -Scope CurrentUser\"",
                Append, ct);

            if (installExit != 0)
            {
                Append($"\n[!!] Could not install the script from PSGallery (exit {installExit}).");
                Status = "Failed.";
                return;
            }

            // Install-Script drops winget-install.ps1 into the CurrentUser scripts
            // folder, which is not on PATH for this process -- calling it by bare
            // name fails with "not recognized". Resolve the real path first, the
            // same way the CLI tool does.
            Append("\n[>>] Running winget-install…");
            const string runScript =
                "$p = (Get-InstalledScript winget-install -ErrorAction SilentlyContinue).InstalledLocation; " +
                "if ($p) { & (Join-Path $p 'winget-install.ps1') -Force } else { winget-install -Force }";
            int runExit = await _runner.RunAsync("pwsh.exe",
                $"-NoProfile -ExecutionPolicy Bypass -Command \"{runScript}\"",
                Append, ct);

            if (runExit == 0)
            {
                Append("\n[OK] Winget repair complete.");
                Status = "Done.";
            }
            else
            {
                Append($"\n[!!] winget-install exited with code {runExit}.");
                Status = "Failed.";
            }
        }
        catch (OperationCanceledException)
        {
            Output += "\n[Cancelled]";
            Status = "Cancelled.";
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Winget repair failed");
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
