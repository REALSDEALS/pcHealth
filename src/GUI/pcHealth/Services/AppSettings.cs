using NLog;
using System.Text.Json;

namespace pcHealth.Services;

internal sealed class AppSettings : IAppSettings
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    private static readonly string FilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "pcHealth", "settings.json");

    private Dictionary<string, string> _cache = new();
    private bool _loaded;

    public string Get(string key, string fallback = "")
    {
        EnsureLoaded();
        return _cache.TryGetValue(key, out var v) ? v : fallback;
    }

    public bool GetBool(string key, bool fallback = true)
    {
        var raw = Get(key);
        if (raw == "") return fallback;
        return raw.Equals("true", StringComparison.OrdinalIgnoreCase) || raw == "1";
    }

    public void Set(string key, string value)
    {
        EnsureLoaded();
        _cache[key] = value;
        Persist();
    }

    private void EnsureLoaded()
    {
        if (_loaded) return;
        _loaded = true;
        try
        {
            if (File.Exists(FilePath))
                _cache = JsonSerializer.Deserialize<Dictionary<string, string>>(
                    File.ReadAllText(FilePath)) ?? new();
        }
        catch (IOException ex)
        {
            Log.Warn(ex, "Settings load failed");
        }
        catch (JsonException ex)
        {
            Log.Warn(ex, "Settings JSON corrupt, using defaults");
        }
    }

    private void Persist()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            File.WriteAllText(FilePath,
                JsonSerializer.Serialize(_cache, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (IOException ex)
        {
            Log.Error(ex, "Settings save failed");
        }
    }
}
