using NLog;
using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace pcHealth.Services;

internal sealed partial class ProcessRunner : IProcessRunner
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    // .NET only ships UTF-* encodings by default; the OEM code pages (850 on a
    // Dutch install, 437 on a US one) come from this provider.
    static ProcessRunner() => Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);

    private static Encoding OemEncoding =>
        Encoding.GetEncoding(CultureInfo.CurrentCulture.TextInfo.OEMCodePage);

    public async Task<int> RunAsync(
        string fileName,
        string arguments,
        Action<string> onLine,
        CancellationToken ct = default,
        TimeSpan timeout = default,
        Encoding? outputEncoding = null)
    {
        var encoding = outputEncoding ?? OemEncoding;
        var psi = new ProcessStartInfo(fileName, arguments)
        {
            UseShellExecute = false,
            // Nothing is ever typed into these tools. A closed stdin makes a
            // tool that unexpectedly prompts fail instead of hanging forever.
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            StandardOutputEncoding = encoding,
            StandardErrorEncoding = encoding,
        };

        Log.Info("Run {FileName} {Arguments}", fileName, arguments);
        long started = Stopwatch.GetTimestamp();

        using var proc = new Process { StartInfo = psi };
        proc.OutputDataReceived += (_, e) => { if (e.Data is not null) onLine(StripAnsi(e.Data)); };
        proc.ErrorDataReceived += (_, e) => { if (e.Data is not null) onLine(StripAnsi(e.Data)); };

        proc.Start();
        proc.StandardInput.Close();
        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();

        CancellationTokenSource? timeoutCts = null;
        try
        {
            CancellationToken effectiveCt = ct;
            if (timeout > TimeSpan.Zero)
            {
                timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
                timeoutCts.CancelAfter(timeout);
                effectiveCt = timeoutCts.Token;
            }

            await proc.WaitForExitAsync(effectiveCt);
        }
        catch (OperationCanceledException)
        {
            proc.Kill(entireProcessTree: true);
            Log.Info("Killed {FileName} after {Seconds:0.0}s",
                fileName, Stopwatch.GetElapsedTime(started).TotalSeconds);
            throw;
        }
        finally
        {
            timeoutCts?.Dispose();
        }

        Log.Info("Exit {ExitCode} from {FileName} after {Seconds:0.0}s",
            proc.ExitCode, fileName, Stopwatch.GetElapsedTime(started).TotalSeconds);
        return proc.ExitCode;
    }

    // pwsh and third-party scripts colour their output; a TextBlock renders the
    // escapes literally. Stripped here so every page benefits.
    [GeneratedRegex(@"\x1B(?:\[[0-9;?]*[ -/]*[@-~]|\][^\x07\x1B]*(?:\x07|\x1B\\))")]
    private static partial Regex AnsiPattern();

    private static string StripAnsi(string line) => AnsiPattern().Replace(line, string.Empty);
}
