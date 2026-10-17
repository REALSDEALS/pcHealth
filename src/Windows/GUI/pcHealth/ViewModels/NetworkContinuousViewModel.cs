using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using System.Net.NetworkInformation;

namespace pcHealth.ViewModels;

public partial class NetworkContinuousViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    private const string Target = "8.8.8.8";
    private const int MaxOutputLines = 500;

    [ObservableProperty] public partial string Output { get; set; } = "";
    [ObservableProperty] public partial string Stats { get; set; } = "";
    [ObservableProperty] public partial bool IsRunning { get; set; }

    private CancellationTokenSource? _cts;
    private int _sent, _received;
    private readonly Queue<string> _lines = new(MaxOutputLines + 1);
    private Microsoft.UI.Dispatching.DispatcherQueue? _dispatcher;

    [RelayCommand(CanExecute = nameof(CanStart))]
    public async Task StartAsync()
    {
        _dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        _cts = new CancellationTokenSource();
        _sent = 0;
        _received = 0;
        _lines.Clear();
        IsRunning = true;

        AppendLine($"Pinging {Target} continuously...");
        AppendLine("");

        try
        {
            await Task.Run(async () =>
            {
                using var ping = new Ping();
                while (!_cts.Token.IsCancellationRequested)
                {
                    PingReply? reply = null;
                    try { reply = await ping.SendPingAsync(Target, 4000); }
                    catch (Exception ex) { _dispatcher?.TryEnqueue(() => AppendLine($"Error: {ex.Message}")); }

                    if (reply is not null)
                    {
                        var seq = ++_sent;
                        var success = reply.Status == IPStatus.Success;
                        if (success) _received++;

                        var line = success
                            ? $"[{seq,4}]  Reply from {reply.Address}: {reply.RoundtripTime} ms"
                            : $"[{seq,4}]  Timeout ({reply.Status})";
                        var statsStr = $"Sent: {_sent}  Received: {_received}  Loss: {(_sent - _received) * 100 / _sent}%";

                        _dispatcher?.TryEnqueue(() => { AppendLine(line); Stats = statsStr; });
                    }

                    try { await Task.Delay(1000, _cts.Token); }
                    catch (OperationCanceledException) { break; }
                }
            });
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            Log.Error(ex, "Continuous ping failed");
            _dispatcher?.TryEnqueue(() => AppendLine($"\nError: {ex.Message}"));
        }
        finally
        {
            _dispatcher?.TryEnqueue(() => { AppendLine("\n[Stopped]"); IsRunning = false; });
        }
    }

    [RelayCommand(CanExecute = nameof(IsRunning))]
    public void Stop()
    {
        _cts?.Cancel();
    }

    private bool CanStart() => !IsRunning;

    private void AppendLine(string line)
    {
        _lines.Enqueue(line);
        if (_lines.Count > MaxOutputLines) _lines.Dequeue();
        Output = string.Join("\n", _lines);
    }
}
