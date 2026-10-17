namespace pcHealth.Services;

public interface IUpdateChecker
{
    Task<string?> GetLatestTagAsync();
    bool IsNewer(string remoteTag);
    string GetCurrentVersion();
}
