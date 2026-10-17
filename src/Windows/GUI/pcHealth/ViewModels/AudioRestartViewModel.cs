using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using System.ServiceProcess;

namespace pcHealth.ViewModels;

/// <summary>
/// Restarts the Windows audio stack. The Service Control Manager is driven
/// through ServiceController rather than net.exe and sc.exe: the state comes
/// back as an enum instead of the word "RUNNING" somewhere in a wall of text,
/// and WaitForStatus replaces the fixed one-second guess between stop and
/// start.
/// </summary>
public partial class AudioRestartViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(30);

    // Audiosrv depends on AudioEndpointBuilder, so it stops first and starts last.
    private const string Endpoint = "AudioEndpointBuilder";
    private const string Audio = "Audiosrv";

    [ObservableProperty] public partial bool AebRunning { get; set; }
    [ObservableProperty] public partial bool AudioRunning { get; set; }
    [ObservableProperty] public partial bool IsRunning { get; set; }
    [ObservableProperty] public partial bool Succeeded { get; set; }
    [ObservableProperty] public partial string ErrorMessage { get; set; } = "";

    [RelayCommand]
    public async Task LoadStatusAsync()
    {
        try
        {
            (AebRunning, AudioRunning) = await Task.Run(ReadStatus);
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
            (AebRunning, AudioRunning) = await Task.Run(() =>
            {
                Stop(Audio);
                Stop(Endpoint);
                Start(Endpoint);
                Start(Audio);
                return ReadStatus();
            });
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

    private static (bool Endpoint, bool Audio) ReadStatus() => (Running(Endpoint), Running(Audio));

    private static bool Running(string name)
    {
        using var service = new ServiceController(name);
        return service.Status == ServiceControllerStatus.Running;
    }

    private static void Stop(string name)
    {
        Log.Info("Stopping service {Service}", name);
        using var service = new ServiceController(name);
        if (service.Status != ServiceControllerStatus.Stopped
            && service.Status != ServiceControllerStatus.StopPending)
            service.Stop(stopDependentServices: true);
        service.WaitForStatus(ServiceControllerStatus.Stopped, Timeout);
    }

    private static void Start(string name)
    {
        Log.Info("Starting service {Service}", name);
        using var service = new ServiceController(name);
        if (service.Status != ServiceControllerStatus.Running
            && service.Status != ServiceControllerStatus.StartPending)
            service.Start();
        service.WaitForStatus(ServiceControllerStatus.Running, Timeout);
    }
}
