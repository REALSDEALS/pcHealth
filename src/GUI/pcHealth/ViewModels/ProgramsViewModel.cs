using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using pcHealth.Models;
using pcHealth.Services;
using System.Collections.ObjectModel;

namespace pcHealth.ViewModels;

public partial class ProgramsViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();
    private static readonly ProgramItem[] AllPrograms =
    [
        new ProgramItem { Name = "HWiNFO64",              Glyph = "", Note = "Hardware information and real-time monitoring", WingetId = "REALix.HWiNFO",                   ExeName = "HWiNFO64.exe",    RegistryName = "HWiNFO",          Category = "Hardware"  },
        new ProgramItem { Name = "HWMonitor",             Glyph = "", Note = "Voltage, temperature, and fan speed monitor",   WingetId = "CPUID.HWMonitor",                  ExeName = "HWMonitor.exe",   RegistryName = "HWMonitor",       Category = "Hardware"  },
        new ProgramItem { Name = "Prime95",               Glyph = "", Note = "CPU stress test and stability checker",          WingetId = "mersenne.prime95",                 ExeName = "prime95.exe",     RegistryName = "Prime95",         Category = "Hardware"  },
        new ProgramItem { Name = "CrystalDiskInfo",       Glyph = "", Note = "HDD/SSD S.M.A.R.T. health viewer",              WingetId = "CrystalDewWorld.CrystalDiskInfo",  ExeName = "DiskInfo64.exe",  RegistryName = "CrystalDiskInfo", Category = "Disk"      },
        new ProgramItem { Name = "CrystalDiskMark",       Glyph = "", Note = "Disk read/write benchmark tool",                 WingetId = "CrystalDewWorld.CrystalDiskMark", ExeName = "DiskMark64.exe",  RegistryName = "CrystalDiskMark", Category = "Disk"      },
        new ProgramItem { Name = "Malwarebytes AdwCleaner",Glyph = "",Note = "Removes adware, PUPs, and browser hijackers",   WingetId = "Malwarebytes.AdwCleaner",          ExeName = "AdwCleaner.exe",  RegistryName = "AdwCleaner",      Category = "Security"  },
        new ProgramItem { Name = "Windows PowerToys",     Glyph = "", Note = "Power-user utilities by Microsoft",              WingetId = "Microsoft.PowerToys",              ExeName = "PowerToys.exe",   RegistryName = "PowerToys",       Category = "Utilities" },
    ];

    private readonly ICliRunner _cli;

    public ObservableCollection<ItemGroup<ProgramItem>> GroupedPrograms { get; } = new();

    public ProgramsViewModel(ICliRunner cli)
    {
        _cli = cli;
        var categoryOrder = new[] { "Hardware", "Disk", "Security", "Utilities" };
        var groups = AllPrograms
            .GroupBy(p => p.Category)
            .OrderBy(g => { int i = Array.IndexOf(categoryOrder, g.Key); return i < 0 ? 999 : i; });
        foreach (var g in groups)
            GroupedPrograms.Add(new ItemGroup<ProgramItem>(g.Key, g));
    }

    [RelayCommand]
    public async Task CheckInstalledAsync()
    {
        var dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        var tasks = AllPrograms
            .Where(p => !string.IsNullOrEmpty(p.RegistryName))
            .Select(p => Task.Run(() =>
            {
                try
                {
                    bool installed = _cli.IsInstalled(p.RegistryName);
                    dispatcher.TryEnqueue(() => p.IsInstalled = installed);
                }
                catch (Exception ex)
                {
                    Log.Debug(ex, "IsInstalled check failed for {Name}", p.Name);
                }
            }));
        await Task.WhenAll(tasks);
    }

    public void InstallOrOpen(ProgramItem item) => _ = InstallOrOpenCoreAsync(item);

    // Open if installed, install otherwise. Throws on error so callers can show feedback.
    public async Task InstallOrOpenAsync(ProgramItem item)
    {
        if (item.IsInstalled)
        {
            if (!string.IsNullOrEmpty(item.ExeName))
                _cli.OpenApp(item.ExeName, item.RegistryName);
        }
        else if (!string.IsNullOrEmpty(item.WingetId))
        {
            using var p = _cli.RunWinget(
                $"install --id {item.WingetId} --accept-source-agreements --accept-package-agreements");
            await p.WaitForExitAsync();
            await CheckInstalledAsync();
        }
        else if (!string.IsNullOrEmpty(item.BrowserUrl))
        {
            _cli.OpenUri(item.BrowserUrl);
        }
    }

    public async Task UpdateAsync(ProgramItem item)
    {
        if (string.IsNullOrEmpty(item.WingetId)) return;
        using var p = _cli.RunWinget(
            $"upgrade --id {item.WingetId} --accept-source-agreements --accept-package-agreements");
        await p.WaitForExitAsync();
        await CheckInstalledAsync();
    }

    public async Task ForceInstallAsync(ProgramItem item)
    {
        if (string.IsNullOrEmpty(item.WingetId)) return;
        using var p = _cli.RunWinget(
            $"install --id {item.WingetId} --force --accept-source-agreements --accept-package-agreements");
        await p.WaitForExitAsync();
        await CheckInstalledAsync();
    }

    private async Task InstallOrOpenCoreAsync(ProgramItem item)
    {
        try { await InstallOrOpenAsync(item); }
        catch (Exception ex) { Log.Error(ex, "Could not install/open {Name}", item.Name); }
    }
}
