using NLog;
using System.Diagnostics;

namespace pcHealth.Services;

internal sealed class CliRunner : ICliRunner
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    private string? _toolsDir;

    private static readonly string[] UninstallPaths =
    {
        @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    };

    private string GetToolsDir()
    {
        if (_toolsDir is not null) return _toolsDir;

        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "src", "Windows", "CLI", "tools");
            if (Directory.Exists(candidate))
                return _toolsDir = candidate;
            dir = dir.Parent;
        }

        throw new DirectoryNotFoundException(
            "Cannot locate src/Windows/CLI/tools.\n" +
            "Make sure the app is run from within the pcHealth repository.");
    }

    // ShellExecute hands a protocol off to a handler that is already running --
    // Settings, a browser -- without creating a process, so a null return here
    // means someone took the request, not that it failed.
    public void OpenUri(string uri)
    {
        Log.Info("Open {Uri}", uri);
        Process.Start(new ProcessStartInfo { FileName = uri, UseShellExecute = true })?.Dispose();
    }

    public void OpenApp(string exeName, string registryName = "")
    {
        var path = GetAppPathsExe(exeName)
            ?? (!string.IsNullOrEmpty(registryName) ? GetInstallLocationExe(registryName, exeName) : null)
            ?? exeName;
        Log.Info("Open {Path}", path);
        Start(new ProcessStartInfo { FileName = path, UseShellExecute = true });
    }

    private string? GetAppPathsExe(string exeName)
    {
        try
        {
            using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
                $@"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{exeName}");
            return key?.GetValue(null) as string;
        }
        catch (UnauthorizedAccessException ex)
        {
            Log.Debug(ex, "App Paths registry access denied for {ExeName}", exeName);
            return null;
        }
        catch (System.Security.SecurityException ex)
        {
            Log.Debug(ex, "App Paths registry security error for {ExeName}", exeName);
            return null;
        }
    }

    private string? GetInstallLocationExe(string registryName, string exeName)
    {
        try
        {
            foreach (var path in UninstallPaths)
            {
                using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(path);
                if (key is null) continue;

                foreach (var sub in key.GetSubKeyNames())
                {
                    using var entry = key.OpenSubKey(sub);
                    if (entry?.GetValue("DisplayName") is not string displayName
                        || !displayName.Contains(registryName, StringComparison.OrdinalIgnoreCase))
                        continue;

                    if (entry.GetValue("InstallLocation") is string loc && !string.IsNullOrWhiteSpace(loc))
                    {
                        var candidate = Path.Combine(loc.TrimEnd('\\', '/'), exeName);
                        if (File.Exists(candidate)) return candidate;
                    }

                    if (entry.GetValue("DisplayIcon") is string icon)
                    {
                        var iconPath = icon.Split(',')[0].Trim('"');
                        if (iconPath.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) && File.Exists(iconPath))
                            return iconPath;
                    }
                }
            }
        }
        catch (UnauthorizedAccessException ex)
        {
            Log.Debug(ex, "Uninstall registry access denied searching for {RegistryName}", registryName);
        }
        catch (System.Security.SecurityException ex)
        {
            Log.Debug(ex, "Uninstall registry security error searching for {RegistryName}", registryName);
        }
        return null;
    }

    public bool IsInstalled(string registryName)
    {
        if (string.IsNullOrEmpty(registryName)) return false;
        return SearchUninstallKey(Microsoft.Win32.Registry.LocalMachine, registryName)
            || SearchUninstallKey(Microsoft.Win32.Registry.CurrentUser, registryName);
    }

    private bool SearchUninstallKey(Microsoft.Win32.RegistryKey hive, string name)
    {
        try
        {
            foreach (var path in UninstallPaths)
            {
                using var key = hive.OpenSubKey(path);
                if (key is null) continue;

                foreach (var sub in key.GetSubKeyNames())
                {
                    using var entry = key.OpenSubKey(sub);
                    if (entry?.GetValue("DisplayName") is string displayName
                        && displayName.Contains(name, StringComparison.OrdinalIgnoreCase))
                        return true;
                }
            }
        }
        catch (UnauthorizedAccessException ex)
        {
            Log.Debug(ex, "Uninstall registry access denied checking {Name}", name);
        }
        catch (System.Security.SecurityException ex)
        {
            Log.Debug(ex, "Uninstall registry security error checking {Name}", name);
        }
        return false;
    }

    private static Process Start(ProcessStartInfo info)
    {
        return Process.Start(info)
            ?? throw new InvalidOperationException($"Failed to start process: {info.FileName}");
    }
}
