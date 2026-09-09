using CommunityToolkit.Mvvm.ComponentModel;
using pcHealth.Models;
using pcHealth.Pages;
using System.Collections.ObjectModel;

namespace pcHealth.ViewModels;

public partial class ToolsViewModel : ObservableObject
{
    private static readonly ToolItem[] AllTools =
    [
        new ToolItem { Name = "System Information",         Glyph = "",   PageType = typeof(SystemInfoPage),        Category = "Information", Platforms = ["Windows", "Linux"] },
        new ToolItem { Name = "Hardware Information",        Glyph = "",   PageType = typeof(HardwareInfoPage),      Category = "Information", Platforms = ["Windows", "Linux"] },
        new ToolItem { Name = "Windows License Key",         Glyph = "",   PageType = typeof(LicenseKeyPage),        Category = "Information", Platforms = ["Windows"] },
        new ToolItem { Name = "Short Ping Test",             Glyph = "",   PageType = typeof(NetworkPingPage),       Category = "Network",     Platforms = ["Windows", "Linux"] },
        new ToolItem { Name = "Continuous Ping Test",        Glyph = "",   PageType = typeof(NetworkContinuousPage), Category = "Network",     Platforms = ["Windows", "Linux"] },
        new ToolItem { Name = "Traceroute to Google",        Glyph = "",   PageType = typeof(TraceroutePage),        Category = "Network",     Platforms = ["Windows", "Linux"] },
        new ToolItem { Name = "Reset Network Stack",         Glyph = "",   PageType = typeof(NetworkResetPage),      Category = "Network",     Platforms = ["Windows"] },
        new ToolItem { Name = "Disk Optimization",           Glyph = "",   PageType = typeof(DiskOptimizationPage),  Category = "Disk",        Platforms = ["Windows"] },
        new ToolItem { Name = "Disk Cleanup",                Glyph = "",   PageType = typeof(DiskCleanupPage),       Category = "Disk",        Platforms = ["Windows", "Linux"] },
        new ToolItem { Name = "Windows Update",              Glyph = "",   PageType = typeof(WindowsUpdatePage),     Category = "Updates",     Platforms = ["Windows"] },
        new ToolItem { Name = "Update all packages",         Glyph = "",   Note = "winget",                          PageType = typeof(SystemUpdatePage),      Category = "Updates",     Platforms = ["Windows"] },
        new ToolItem { Name = "Update HP Drivers",           Glyph = "",   Note = "HP only",                         PageType = typeof(HPUpdatePage),          Category = "Updates",     Platforms = ["Windows"] },
        new ToolItem { Name = "Get Ninite",                  Glyph = "",   Note = "Edge, Chrome, VLC, 7-Zip",        PageType = typeof(NinitePage),            Category = "Updates",     Platforms = ["Windows"] },
        new ToolItem { Name = "Scan + Repair",               Glyph = "",   Note = "SFC + DISM combined",             PageType = typeof(ScanRepairPage),        Category = "Maintenance", Platforms = ["Windows"] },
        new ToolItem { Name = "Repair Boot Record",          Glyph = "",   Note = "use with caution!",               PageType = typeof(BootRepairPage),        Category = "Maintenance", Platforms = ["Windows"] },
        new ToolItem { Name = "Open CBS Log",                Glyph = "",   PageType = typeof(CBSLogPage),            Category = "Maintenance", Platforms = ["Windows"] },
        new ToolItem { Name = "Repair Winget",               Glyph = "",   PageType = typeof(WingetRepairPage),      Category = "Maintenance", Platforms = ["Windows"] },
        new ToolItem { Name = "BIOS Password Recovery",      Glyph = "",   PageType = typeof(BIOSPasswordPage),      Category = "Security",    Platforms = ["Windows", "Linux"] },
        new ToolItem { Name = "Battery Report",              Glyph = "",   Note = "laptop only",                     PageType = typeof(BatteryReportPage),     Category = "Hardware",    Platforms = ["Windows"] },
        new ToolItem { Name = "Open Battery Report",         Glyph = "",   PageType = typeof(OpenBatteryReportPage), Category = "Hardware",    Platforms = ["Windows"] },
        new ToolItem { Name = "Restart Audio Drivers",       Glyph = "",   PageType = typeof(AudioRestartPage),      Category = "Hardware",    Platforms = ["Windows"] },
        new ToolItem { Name = "Shutdown / Reboot / Log Off", Glyph = "",   PageType = typeof(PowerOptionsPage),      Category = "System",      Platforms = ["Windows", "Linux"] },
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
