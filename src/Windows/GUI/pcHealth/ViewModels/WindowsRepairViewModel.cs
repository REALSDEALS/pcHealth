using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using pcHealth.Helpers;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class WindowsRepairViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    private readonly IWindowsRepair _repair;

    [ObservableProperty] public partial string Status { get; set; } = "";
    [ObservableProperty] public partial bool IsBusy { get; set; }

    /// <summary>Set by the page: a ContentDialog needs somewhere to render.</summary>
    public XamlRoot? XamlRoot { get; set; }

    public WindowsRepairViewModel(IWindowsRepair repair) => _repair = repair;

    [RelayCommand]
    public void OpenRecovery() => _repair.OpenRecovery();

    [RelayCommand(CanExecute = nameof(CanStart))]
    public async Task StartAsync(CancellationToken ct)
    {
        if (XamlRoot is null)
        {
            Status = "The page is not ready yet. Try again.";
            return;
        }

        bool confirmed = await DialogHelper.ShowConfirmAsync(
            XamlRoot,
            "Repair Windows",
            "Windows will download a clean copy of the version you are running -- around 8 GB -- and "
            + "rebuild the system from it. Your files, apps and settings are kept.\n\n"
            + "The current install is moved aside to C:\\Windows.old, so keep 25 to 30 GB free. It "
            + "takes roughly half an hour to an hour and ends in a restart. Stay on mains power and "
            + "online, and save your work first.",
            "Start repair");

        if (!confirmed)
        {
            Status = "Cancelled.";
            return;
        }

        IsBusy = true;
        Status = "Opening Windows Update and asking it to start the repair...";
        try
        {
            var result = await _repair.StartAsync(ct);
            Status = result.Message;
        }
        catch (OperationCanceledException)
        {
            Status = "Cancelled.";
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Windows repair failed");
            Status = ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    private bool CanStart() => !IsBusy;
}
