using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class BIOSPasswordViewModel : ObservableObject
{
    private readonly ICliRunner _cli;

    public BIOSPasswordViewModel(ICliRunner cli) => _cli = cli;

    [RelayCommand]
    public void OpenBiosPw() => _cli.OpenUri("https://bios-pw.org");

    [RelayCommand]
    public void OpenRepo() => _cli.OpenUri("https://github.com/bacher09/pwgen-for-bios");
}
