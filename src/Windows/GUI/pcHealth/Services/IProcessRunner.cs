namespace pcHealth.Services;

public interface IProcessRunner
{
    /// <summary>Runs a process and returns its exit code.</summary>
    Task<int> RunAsync(
        string fileName,
        string arguments,
        Action<string> onLine,
        CancellationToken ct = default,
        TimeSpan timeout = default);
}
