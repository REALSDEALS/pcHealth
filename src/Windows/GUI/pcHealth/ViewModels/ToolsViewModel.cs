using CommunityToolkit.Mvvm.ComponentModel;
using pcHealth.Models;
using pcHealth.Pages;
using System.Collections.ObjectModel;

namespace pcHealth.ViewModels;

public partial class ToolsViewModel : ObservableObject
{
    private static readonly ToolItem[] AllTools =
    [
        new ToolItem { Name = "System Information",         Glyph = "\uE946", PageType = typeof(SystemInfoPage),        Category = "Information", Platforms = ["Windows", "Linux"] },
        new ToolItem { Name = "Hardware Information",        Glyph = "\uE950", PageType = typeof(HardwareInfoPage),      Category = "Information", Platforms = ["Windows", "Linux"] },
        new ToolItem { Name = "Windows License Key",         Glyph = "\uE8D7", PageType = typeof(LicenseKeyPage),        Category = "Information", Platforms = ["Windows"] },
        new ToolItem { Name = "Short Ping Test",             Glyph = "\uE701", PageType = typeof(NetworkPingPage),       Category = "Network",     Platforms = ["Windows", "Linux"] },
        new ToolItem { Name = "Continuous Ping Test",        Glyph = "\uE895", PageType = typeof(NetworkContinuousPage), Category = "Network",     Platforms = ["Windows", "Linux"] },
        new ToolItem { Name = "Traceroute to Google",        Glyph = "\uE774", PageType = typeof(TraceroutePage),        Category = "Network",     Platforms = ["Windows", "Linux"] },
        new ToolItem { Name = "Reset Network Stack",         Glyph = "\uE72C", PageType = typeof(NetworkResetPage),      Category = "Network",     Platforms = ["Windows"] },
        new ToolItem { Name = "Disk Optimization",           Glyph = "\uEDA2", PageType = typeof(DiskOptimizationPage),  Category = "Disk",        Platforms = ["Windows"] },
        new ToolItem { Name = "Disk Cleanup",                Glyph = "\uE74D", PageType = typeof(DiskCleanupPage),       Category = "Disk",        Platforms = ["Windows", "Linux"] },
        new ToolItem { Name = "Windows Update",              Glyph = "\uE777", PageType = typeof(WindowsUpdatePage),     Category = "Updates",     Platforms = ["Windows"] },
        new ToolItem { Name = "Update all packages",         Glyph = "\uE7B8", Note = "winget",                          PageType = typeof(SystemUpdatePage),      Category = "Updates",     Platforms = ["Windows"] },
        new ToolItem { Name = "Update HP Drivers",           Glyph = "\uE7F8", Note = "HP only",                         PageType = typeof(HPUpdatePage),          Category = "Updates",     Platforms = ["Windows"] },
        new ToolItem { Name = "Get Ninite",                  Glyph = "\uE896", Note = "Edge, Chrome, VLC, 7-Zip",        PageType = typeof(NinitePage),            Category = "Updates",     Platforms = ["Windows"] },
        new ToolItem { Name = "Scan + Repair",               Glyph = "\uE9D9", Note = "SFC + DISM combined",             PageType = typeof(ScanRepairPage),        Category = "Maintenance", Platforms = ["Windows"] },
        new ToolItem { Name = "Repair Windows",              Glyph = "\uE770", Note = "keeps files and apps",            PageType = typeof(WindowsRepairPage),      Category = "Maintenance", Platforms = ["Windows"] },
        new ToolItem { Name = "Repair Boot Record",          Glyph = "\uE7BA", Note = "use with caution!",               PageType = typeof(BootRepairPage),        Category = "Maintenance", Platforms = ["Windows"] },
        new ToolItem { Name = "Open CBS Log",                Glyph = "\uE8A5", PageType = typeof(CBSLogPage),            Category = "Maintenance", Platforms = ["Windows"] },
        new ToolItem { Name = "Repair Winget",               Glyph = "\uE90F", PageType = typeof(WingetRepairPage),      Category = "Maintenance", Platforms = ["Windows"] },
        new ToolItem { Name = "BIOS Password Recovery",      Glyph = "\uE72E", PageType = typeof(BIOSPasswordPage),      Category = "Security",    Platforms = ["Windows", "Linux"] },
        new ToolItem { Name = "Battery Report",              Glyph = "\uE83F", Note = "laptop only",                     PageType = typeof(BatteryReportPage),     Category = "Hardware",    Platforms = ["Windows"] },
        new ToolItem { Name = "Open Battery Report",         Glyph = "\uE8E5", PageType = typeof(OpenBatteryReportPage), Category = "Hardware",    Platforms = ["Windows"] },
        new ToolItem { Name = "Restart Audio Drivers",       Glyph = "\uE767", PageType = typeof(AudioRestartPage),      Category = "Hardware",    Platforms = ["Windows"] },
        new ToolItem { Name = "Shutdown / Reboot / Log Off", Glyph = "\uE7E8", PageType = typeof(PowerOptionsPage),      Category = "System",      Platforms = ["Windows", "Linux"] },
    ];

    public ObservableCollection<ItemGroup<ToolItem>> GroupedTools { get; } = new();

    public ToolsViewModel()
    {
        bool isWindows = OperatingSystem.IsWindows();
        var categoryOrder = new[] { "Information", "Network", "Disk", "Updates", "Maintenance", "Security", "Hardware", "System" };
        var groups = AllTools
            .Where(t => isWindows ? t.Platforms.Contains("Windows") : t.Platforms.Contains("Linux"))
            .GroupBy(t => t.Category)
            .OrderBy(g => { int i = Array.IndexOf(categoryOrder, g.Key); return i < 0 ? 999 : i; });

        foreach (var g in groups)
            GroupedTools.Add(new ItemGroup<ToolItem>(g.Key, g));
    }
}
