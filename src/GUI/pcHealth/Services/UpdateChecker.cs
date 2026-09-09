using NLog;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Reflection;
using System.Text.Json;

namespace pcHealth.Services;

internal sealed class UpdateChecker : IUpdateChecker
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    private const string ReleasesApi =
        "https://api.github.com/repos/REALSDEALS/pcHealth/releases/latest";

    private readonly HttpClient _http;

    public UpdateChecker()
    {
        _http = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
        _http.DefaultRequestHeaders.UserAgent.Add(
            new ProductInfoHeaderValue("pcHealth", GetCurrentVersion()));
    }

    public async Task<string?> GetLatestTagAsync()
    {
        try
        {
            using var response = await _http.GetAsync(ReleasesApi);
            if (!response.IsSuccessStatusCode) return null;

            using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            return doc.RootElement.GetProperty("tag_name").GetString();
        }
        catch (HttpRequestException ex)
        {
            Log.Debug(ex, "Update check network error");
            return null;
        }
        catch (JsonException ex)
        {
            Log.Debug(ex, "Update check JSON parse error");
            return null;
        }
    }

    public bool IsNewer(string remoteTag)
    {
        var current = Assembly.GetExecutingAssembly().GetName().Version;
        if (current is null) return false;

        var clean = remoteTag.TrimStart('v', 'V').Trim();
        var dashIdx = clean.IndexOf('-');
        if (dashIdx > 0) clean = clean[..dashIdx];
        return Version.TryParse(clean, out var remote) && remote > current;
    }

    public string GetCurrentVersion()
    {
        var v = Assembly.GetExecutingAssembly().GetName().Version;
        return v is not null ? $"{v.Major}.{v.Minor}.{v.Build}" : "unknown";
    }
}
