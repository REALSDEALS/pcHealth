namespace pcHealth.Services;

public interface ICliRunner
{
    void OpenUri(string uri);
    void OpenApp(string exeName, string registryName = "");
    bool IsInstalled(string registryName);
}
