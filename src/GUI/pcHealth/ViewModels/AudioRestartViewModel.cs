using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class AudioRestartViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();
    private readonly IProcessRunner _runner;

    [ObservableProperty] public partial bool AebRunning { get; set; }
    [ObservableProperty] public partial bool AudioRunning { get; set; }
    [ObservableProperty] public partial bool IsRunning { get; set; }
    [ObservableProperty] public partial bool Succeeded { get; set; }
    [ObservableProperty] public partial string ErrorMessage { get; set; } = "";

    public AudioRestartViewModel(IProcessRunner runner) => _runner = runner;

    [RelayCommand]
    public async Task LoadStatusAsync()
    {
        try
        {
            AebRunning = await IsServiceRunningAsync("AudioEndpointBuilder");
            AudioRunning = await IsServiceRunningAsync("Audiosrv");
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Audio service status check failed");
            ErrorMessage = ex.Message;
        }
    }

    [RelayCommand(CanExecute = nameof(CanRestart))]
    public async Task RestartAsync()
    {
        IsRunning = true;
        Succeeded = false;
        ErrorMessage = "";
        try
        {
            await _runner.RunAsync("net.exe", "stop Audiosrv /yes", _ => { });
            await _runner.RunAsync("net.exe", "stop AudioEndpointBuilder /yes", _ => { });
            await Task.Delay(1000);
            await _runner.RunAsync("net.exe", "start AudioEndpointBuilder", _ => { });
            await _runner.RunAsync("net.exe", "start Audiosrv", _ => { });
            AebRunning = await IsServiceRunningAsync("AudioEndpointBuilder");
            AudioRunning = await IsServiceRunningAsync("Audiosrv");
            Succeeded = true;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Audio service restart failed");
            ErrorMessage = ex.Message;
        }
        finally
        {
            IsRunning = false;
        }
    }

    private bool CanRestart() => !IsRunning;

    private async Task<bool> IsServiceRunningAsync(string name)
    {
        var sb = new System.Text.StringBuilder();
        await _runner.RunAsync("sc.exe", $"query {name}", line => sb.AppendLine(line));
        return sb.ToString().Contains("RUNNING", StringComparison.OrdinalIgnoreCase);
    }
}
