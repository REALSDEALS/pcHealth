namespace pcHealth.Services;

public interface IAppSettings
{
    string Get(string key, string fallback = "");
    bool GetBool(string key, bool fallback = true);
    void Set(string key, string value);
}
