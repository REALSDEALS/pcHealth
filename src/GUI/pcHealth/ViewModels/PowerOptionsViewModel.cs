using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using System.Diagnostics;

namespace pcHealth.ViewModels;

public partial class PowerOptionsViewModel : ObservableObject
{
    // Confirmation dialogs stay in code-behind (need XamlRoot).
    // The page calls these methods after user confirms.

    [RelayCommand]
    public void LogOff() => RunShutdown("/l");

    [RelayCommand]
    public void Restart() => RunShutdown("/r", "/t", "0");

    [RelayCommand]
    public void Shutdown() => RunShutdown("/s", "/t", "0");

    private static void RunShutdown(params string[] args)
    {
        var psi = new ProcessStartInfo { FileName = "shutdown.exe", CreateNoWindow = true };
        foreach (var a in args) psi.ArgumentList.Add(a);
        Process.Start(psi);
    }
}
