using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class DiskCleanupViewModel : ObservableObject
{
    private readonly ICliRunner _cli;

    public DiskCleanupViewModel(ICliRunner cli) => _cli = cli;

    [RelayCommand]
    public void Open() => _cli.OpenApp("cleanmgr.exe");
}
