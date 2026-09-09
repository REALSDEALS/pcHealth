using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class DiskOptimizationViewModel : ObservableObject
{
    private readonly ICliRunner _cli;

    public DiskOptimizationViewModel(ICliRunner cli) => _cli = cli;

    [RelayCommand]
    public void Open() => _cli.OpenApp("dfrgui.exe");
}
