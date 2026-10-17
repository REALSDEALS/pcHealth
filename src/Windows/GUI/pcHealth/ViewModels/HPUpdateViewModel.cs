using CommunityToolkit.Mvvm.Input;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class HPUpdateViewModel : WinGetViewModel
{
    private const string ImageAssistant = "HP.ImageAssistant";

    public HPUpdateViewModel(IWinGet winGet) : base(winGet) { }

    [RelayCommand(CanExecute = nameof(CanStart), IncludeCancelCommand = true)]
    public Task InstallAsync(CancellationToken ct) =>
        ExecuteAsync(progress => WinGet.InstallAsync(ImageAssistant, progress, force: false, ct), "Starting...");
}
