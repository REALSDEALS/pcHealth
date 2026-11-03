namespace pcHealth.Services;

public interface IProcessRunner
{
    /// <summary>Runs a process and returns its exit code.</summary>
    /// <param name="outputEncoding">
    /// How the child writes to a pipe. Defaults to the OEM code page, which is
    /// what console tools such as dism, netsh and bcdboot use. sfc writes
    /// UTF-16 (<see cref="System.Text.Encoding.Unicode"/>), winget UTF-8.
    /// </param>
    Task<int> RunAsync(
        string fileName,
        string arguments,
        Action<string> onLine,
        CancellationToken ct = default,
        TimeSpan timeout = default,
        System.Text.Encoding? outputEncoding = null);
}
