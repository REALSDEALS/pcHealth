using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace pcHealth.ViewModels;

public partial class TracerouteViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    private const string Target = "google.com";
    private const int MaxHops = 30;
    private const int TimeoutMs = 4000;

    public record HopResult(int Hop, string Address, string Latency, bool Reached);

    [ObservableProperty] public partial bool IsRunning { get; set; }
    [ObservableProperty] public partial string Status { get; set; } = "";
    [ObservableProperty] public partial IReadOnlyList<HopResult> Hops { get; set; } = [];

    [RelayCommand(CanExecute = nameof(CanRun), IncludeCancelCommand = true)]
    public async Task RunAsync(CancellationToken ct)
    {
        IsRunning = true;
        Hops = [];
        Status = $"Tracing route to {Target}…";

        var results = new List<HopResult>();
        var dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();

        try
        {
            IPAddress? targetAddress = null;
            try
            {
                var addresses = await Dns.GetHostAddressesAsync(Target);
                targetAddress = addresses.FirstOrDefault(a => a.AddressFamily == AddressFamily.InterNetwork)
                    ?? addresses.FirstOrDefault();
            }
            catch (Exception ex) when (ex is SocketException or ArgumentException)
            {
                // Not fatal: the trace still runs, it just cannot mark the final hop.
                // ArgumentException covers a malformed target the user typed.
                Log.Debug(ex, "Could not resolve {Target}", Target);
            }

            await Task.Run(async () =>
            {
                using var ping = new Ping();
                for (int ttl = 1; ttl <= MaxHops && !ct.IsCancellationRequested; ttl++)
                {
                    var options = new PingOptions(ttl, dontFragment: true);
                    PingReply? reply = null;
                    try { reply = await ping.SendPingAsync(Target, TimeoutMs, new byte[32], options); }
                    catch (Exception ex)
                    {
                        var hop = new HopResult(ttl, "*", $"Error: {ex.Message}", false);
                        dispatcher.TryEnqueue(() => { results.Add(hop); Hops = [.. results]; });
                        continue;
                    }

                    var address = reply.Address?.ToString() ?? "*";
                    var latency = reply.Status is IPStatus.Success or IPStatus.TtlExpired
                        ? $"{reply.RoundtripTime} ms" : "*";
                    var reached = reply.Status == IPStatus.Success;
                    var hopResult = new HopResult(ttl, address, latency, reached);
                    dispatcher.TryEnqueue(() => { results.Add(hopResult); Hops = [.. results]; });

                    if (reached) break;
                }
            }, ct);

            Status = targetAddress is not null ? $"Destination: {targetAddress}" : "Done.";
        }
        catch (OperationCanceledException) { Status = "Cancelled."; }
        catch (Exception ex)
        {
            Log.Error(ex, "Traceroute failed");
            Status = $"Error: {ex.Message}";
        }
        finally
        {
            IsRunning = false;
        }
    }

    private bool CanRun() => !IsRunning;
}
