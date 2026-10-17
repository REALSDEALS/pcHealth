using CommunityToolkit.Mvvm.Input;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class SystemUpdateViewModel : WinGetViewModel
{
    public SystemUpdateViewModel(IWinGet winGet) : base(winGet) { }

    [RelayCommand(CanExecute = nameof(CanStart), IncludeCancelCommand = true)]
    public Task RunAsync(CancellationToken ct) =>
        ExecuteAsync(progress => WinGet.UpgradeAllAsync(progress, ct), "Looking for updates...");
}
