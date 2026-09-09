using System.Diagnostics;
using System.Text.RegularExpressions;

namespace pcHealth.Services;

internal sealed partial class ProcessRunner : IProcessRunner
{
    public async Task<int> RunAsync(
        string fileName,
        string arguments,
        Action<string> onLine,
        CancellationToken ct = default,
        TimeSpan timeout = default)
    {
        var psi = new ProcessStartInfo(fileName, arguments)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            StandardOutputEncoding = System.Text.Encoding.UTF8,
            StandardErrorEncoding = System.Text.Encoding.UTF8,
        };

        using var proc = new Process { StartInfo = psi };
        proc.OutputDataReceived += (_, e) => { if (e.Data is not null) onLine(StripAnsi(e.Data)); };
        proc.ErrorDataReceived += (_, e) => { if (e.Data is not null) onLine(StripAnsi(e.Data)); };

        proc.Start();
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
            throw;
        }
        finally
        {
            timeoutCts?.Dispose();
        }

        return proc.ExitCode;
    }

    // pwsh and third-party scripts colour their output; a TextBlock renders the
    // escapes literally. Stripped here so every page benefits.
    [GeneratedRegex(@"\x1B(?:\[[0-9;?]*[ -/]*[@-~]|\][^\x07\x1B]*(?:\x07|\x1B\\))")]
    private static partial Regex AnsiPattern();

    private static string StripAnsi(string line) => AnsiPattern().Replace(line, string.Empty);
}
