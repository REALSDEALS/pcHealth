using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using System.Net.NetworkInformation;

namespace pcHealth.ViewModels;

public partial class NetworkPingViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    private const string Target = "8.8.8.8";
    private const int Count = 4;

    [ObservableProperty] public partial bool IsRunning { get; set; }
    [ObservableProperty] public partial string ErrorMessage { get; set; } = "";
    [ObservableProperty] public partial IReadOnlyList<PingResult> Results { get; set; } = [];
    [ObservableProperty] public partial IReadOnlyList<(string Label, string Value)> Summary { get; set; } = [];
    [ObservableProperty] public partial bool HasResults { get; set; }

    public record PingResult(bool Success, string Address, long Latency, string Status);

    [RelayCommand(CanExecute = nameof(CanRun), IncludeCancelCommand = true)]
    public async Task RunAsync(CancellationToken ct)
    {
        IsRunning = true;
        HasResults = false;
        Results = [];
        Summary = [];
        ErrorMessage = "";

        try
        {
            var raw = await Task.Run(() =>
            {
                var list = new List<PingResult>();
                using var ping = new Ping();
                for (int i = 0; i < Count; i++)
                {
                    ct.ThrowIfCancellationRequested();
                    try
                    {
                        var reply = ping.Send(Target, 4000);
                        list.Add(reply.Status == IPStatus.Success
                            ? new PingResult(true, reply.Address.ToString(), reply.RoundtripTime, "Reply")
                            : new PingResult(false, Target, 0, reply.Status.ToString()));
                    }
                    catch (OperationCanceledException) { throw; }
                    catch (Exception ex) { list.Add(new PingResult(false, Target, 0, ex.Message)); }
                }
                return list;
            }, ct);

            var latencies = raw.Where(r => r.Success).Select(r => r.Latency).ToList();
            var summaryList = new List<(string, string)>
            {
                ("Packets sent", $"{Count}"),
                ("Packets received", $"{latencies.Count}"),
                ("Packet loss", $"{(Count - latencies.Count) * 100 / Count}%"),
            };
            if (latencies.Count > 0)
            {
                summaryList.Add(("Min latency", $"{latencies.Min()} ms"));
                summaryList.Add(("Max latency", $"{latencies.Max()} ms"));
                summaryList.Add(("Average latency", $"{latencies.Average():0.0} ms"));
            }

            Results = raw;
            Summary = summaryList;
            HasResults = true;
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            Log.Error(ex, "Ping failed");
            ErrorMessage = ex.Message;
        }
        finally
        {
            IsRunning = false;
        }
    }

    private bool CanRun() => !IsRunning;
}
