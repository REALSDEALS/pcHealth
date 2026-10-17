using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class WindowsUpdateViewModel : ObservableObject
{
    private readonly ICliRunner _cli;

    public WindowsUpdateViewModel(ICliRunner cli) => _cli = cli;

    [RelayCommand]
    public void Open() => _cli.OpenUri("ms-settings:windowsupdate");
}
