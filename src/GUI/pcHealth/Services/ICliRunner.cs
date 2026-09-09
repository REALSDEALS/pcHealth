namespace pcHealth.Services;

public interface ICliRunner
{
    void RunScript(string scriptFileName);
    void OpenUri(string uri);
    void OpenApp(string exeName, string registryName = "");
    System.Diagnostics.Process RunWinget(string wingetArguments);
    bool IsInstalled(string registryName);
}
