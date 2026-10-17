using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Management.Infrastructure;
using NLog;

namespace pcHealth.ViewModels;

public partial class SystemInfoViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    [ObservableProperty] public partial bool IsLoading { get; set; } = true;
    [ObservableProperty] public partial string ErrorMessage { get; set; } = "";

    public List<(string Label, string Value)> OsRows { get; } = new();
    public List<(string Label, string Value)> MachineRows { get; } = new();
    public List<(string Label, string Value)> FirmwareRows { get; } = new();
    public List<(string Label, string Value)> HardwareRows { get; } = new();

    private string _copyText = "";
    public string CopyText => _copyText;

    [RelayCommand]
    public async Task LoadAsync()
    {
        try
        {
            var data = await Task.Run(GatherData);
            OsRows.AddRange(data.Os);
            MachineRows.AddRange(data.Machine);
            FirmwareRows.AddRange(data.Firmware);
            HardwareRows.AddRange(data.Hardware);

            var sb = new System.Text.StringBuilder();
            sb.AppendLine("pcHealth - System Information");
            sb.AppendLine($"Generated: {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC");
            sb.AppendLine();
            AppendSection(sb, "Operating System", data.Os);
            AppendSection(sb, "Machine", data.Machine);
            AppendSection(sb, "Firmware & Security", data.Firmware);
            AppendSection(sb, "Hardware Summary", data.Hardware);
            _copyText = sb.ToString();
        }
        catch (Exception ex)
        {
            Log.Error(ex, "System info gather failed");
            ErrorMessage = ex.Message;
        }
        finally
        {
            IsLoading = false;
        }
    }

    private static (
        List<(string, string)> Os,
        List<(string, string)> Machine,
        List<(string, string)> Firmware,
        List<(string, string)> Hardware
    ) GatherData()
    {
        var os = new List<(string, string)>();
        var machine = new List<(string, string)>();
        var firmware = new List<(string, string)>();
        var hardware = new List<(string, string)>();

        using var session = CimSession.Create(null);

        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT Caption, BuildNumber, OSArchitecture, LastBootUpTime, InstallDate, SystemDirectory " +
            "FROM Win32_OperatingSystem"))
        {
            os.Add(("OS Name", inst.CimInstanceProperties["Caption"]?.Value?.ToString() ?? "Unknown"));
            var buildNum = inst.CimInstanceProperties["BuildNumber"]?.Value?.ToString() ?? "";
            try
            {
                using var ntKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
                    @"SOFTWARE\Microsoft\Windows NT\CurrentVersion");
                var displayVer = ntKey?.GetValue("DisplayVersion") as string;
                var ubr = ntKey?.GetValue("UBR");
                var fullBuild = ubr is not null ? $"{buildNum}.{ubr}" : buildNum;
                if (!string.IsNullOrEmpty(displayVer)) os.Add(("Windows Version", displayVer));
                os.Add(("OS Build", fullBuild));
            }
            catch { os.Add(("OS Build", buildNum)); }

            os.Add(("Architecture", inst.CimInstanceProperties["OSArchitecture"]?.Value?.ToString() ?? "Unknown"));
            if (inst.CimInstanceProperties["LastBootUpTime"]?.Value is DateTime lastBoot)
                os.Add(("Last Boot", lastBoot.ToString("yyyy-MM-dd HH:mm:ss")));
            if (inst.CimInstanceProperties["InstallDate"]?.Value is DateTime installDate)
                os.Add(("Install Date", installDate.ToString("yyyy-MM-dd")));
            os.Add(("System Directory", inst.CimInstanceProperties["SystemDirectory"]?.Value?.ToString() ?? "Unknown"));
            break;
        }

        machine.Add(("Computer Name", Environment.MachineName));
        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT Manufacturer, Model, TotalPhysicalMemory FROM Win32_ComputerSystem"))
        {
            machine.Add(("Manufacturer", inst.CimInstanceProperties["Manufacturer"]?.Value?.ToString() ?? "Unknown"));
            machine.Add(("Model", inst.CimInstanceProperties["Model"]?.Value?.ToString() ?? "Unknown"));
            if (inst.CimInstanceProperties["TotalPhysicalMemory"]?.Value is ulong ram)
                hardware.Add(("Total RAM", $"{Math.Round(ram / 1073741824.0, 2)} GB"));
            break;
        }

        foreach (var inst in session.QueryInstances("root/cimv2", "WQL", "SELECT Name FROM Win32_Processor"))
        {
            hardware.Add(("Processor", inst.CimInstanceProperties["Name"]?.Value?.ToString()?.Trim() ?? "Unknown"));
            break;
        }

        try
        {
            using var ctrlKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control");
            firmware.Add(("Firmware Type", ctrlKey?.GetValue("PEFirmwareType") is int t
                ? (t == 2 ? "UEFI" : t == 1 ? "BIOS" : "Unknown") : "Unknown"));
        }
        catch { firmware.Add(("Firmware Type", "Unknown")); }

        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT SMBIOSBIOSVersion, ReleaseDate FROM Win32_BIOS"))
        {
            firmware.Add(("Firmware Version", inst.CimInstanceProperties["SMBIOSBIOSVersion"]?.Value?.ToString() ?? "Unknown"));
            if (inst.CimInstanceProperties["ReleaseDate"]?.Value is DateTime fwDate)
                firmware.Add(("Firmware Date", fwDate.ToString("yyyy-MM-dd")));
            break;
        }

        try
        {
            using var sbKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\SecureBoot\State");
            firmware.Add(("Secure Boot", sbKey?.GetValue("UEFISecureBootEnabled") is int sb
                ? (sb == 1 ? "Enabled" : "Disabled") : "N/A"));
        }
        catch { firmware.Add(("Secure Boot", "N/A")); }

        try
        {
            foreach (var inst in session.QueryInstances("root/cimv2/security/microsofttpm", "WQL",
                "SELECT SpecVersion FROM Win32_Tpm"))
            {
                var spec = inst.CimInstanceProperties["SpecVersion"]?.Value?.ToString();
                firmware.Add(("TPM Version", !string.IsNullOrEmpty(spec) ? spec.Split(',')[0].Trim() : "N/A"));
                break;
            }
        }
        catch { firmware.Add(("TPM Version", "N/A")); }

        return (os, machine, firmware, hardware);
    }

    private static void AppendSection(System.Text.StringBuilder sb, string title, List<(string Label, string Value)> rows)
    {
        sb.AppendLine(title);
        foreach (var (label, value) in rows)
            sb.AppendLine($"  {label,-22}: {value}");
        sb.AppendLine();
    }
}
