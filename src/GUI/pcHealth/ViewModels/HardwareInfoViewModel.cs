using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Management.Infrastructure;
using NLog;

namespace pcHealth.ViewModels;

public partial class HardwareInfoViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    [ObservableProperty] public partial bool IsLoading { get; set; } = true;
    [ObservableProperty] public partial string ErrorMessage { get; set; } = "";

    public List<(string Label, string Value)> CpuRows { get; } = new();
    public List<(string Label, string Value)> GpuRows { get; } = new();
    public List<(string Label, string Value)> RamRows { get; } = new();
    public List<(string Label, string Value)> StorageRows { get; } = new();
    public List<(string Label, string Value)> ChipsetRows { get; } = new();

    private string _copyText = "";
    public string CopyText => _copyText;

    [RelayCommand]
    public async Task LoadAsync()
    {
        try
        {
            var data = await Task.Run(GatherData);
            CpuRows.AddRange(data.Cpu);
            GpuRows.AddRange(data.Gpu);
            RamRows.AddRange(data.Ram);
            StorageRows.AddRange(data.Storage);
            ChipsetRows.AddRange(data.Chipset);

            var sb = new System.Text.StringBuilder();
            sb.AppendLine("pcHealth - Hardware Information");
            sb.AppendLine($"Generated: {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC");
            sb.AppendLine();
            AppendSection(sb, "CPU", data.Cpu);
            AppendSection(sb, "GPU", data.Gpu);
            AppendSection(sb, "Memory (RAM)", data.Ram);
            AppendSection(sb, "Storage", data.Storage);
            AppendSection(sb, "Chipset", data.Chipset);
            _copyText = sb.ToString();
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Hardware info gather failed");
            ErrorMessage = ex.Message;
        }
        finally
        {
            IsLoading = false;
        }
    }

    private static (
        List<(string, string)> Cpu,
        List<(string, string)> Gpu,
        List<(string, string)> Ram,
        List<(string, string)> Storage,
        List<(string, string)> Chipset
    ) GatherData()
    {
        var cpu = new List<(string, string)>();
        var gpu = new List<(string, string)>();
        var ram = new List<(string, string)>();
        var storage = new List<(string, string)>();
        var chipset = new List<(string, string)>();

        using var session = CimSession.Create(null);

        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed FROM Win32_Processor"))
        {
            cpu.Add(("Name", inst.CimInstanceProperties["Name"]?.Value?.ToString()?.Trim() ?? "Unknown"));
            cpu.Add(("Cores", inst.CimInstanceProperties["NumberOfCores"]?.Value?.ToString() ?? "?"));
            cpu.Add(("Threads", inst.CimInstanceProperties["NumberOfLogicalProcessors"]?.Value?.ToString() ?? "?"));
            if (inst.CimInstanceProperties["MaxClockSpeed"]?.Value is uint mhz)
                cpu.Add(("Base Speed", $"{mhz} MHz"));
        }

        var regVram = ReadGpuVramFromRegistry();
        int gpuIdx = 0;
        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT Name, VideoProcessor, DriverVersion, DriverDate, AdapterRAM FROM Win32_VideoController"))
        {
            var name = inst.CimInstanceProperties["Name"]?.Value?.ToString() ?? "Unknown";
            var prefix = gpuIdx > 0 ? $"GPU {gpuIdx + 1} - " : "";
            gpu.Add(($"{prefix}Name", name));
            gpu.Add(($"{prefix}Video Processor", inst.CimInstanceProperties["VideoProcessor"]?.Value?.ToString() ?? "N/A"));
            gpu.Add(($"{prefix}Driver Version", inst.CimInstanceProperties["DriverVersion"]?.Value?.ToString() ?? "N/A"));
            if (inst.CimInstanceProperties["DriverDate"]?.Value is DateTime drvDate)
                gpu.Add(($"{prefix}Driver Date", drvDate.ToString("yyyy-MM-dd")));

            string vramStr = "Shared / Unknown";
            if (regVram.TryGetValue(name, out var regBytes) && regBytes > 0)
                vramStr = $"{Math.Round(regBytes / 1073741824.0, 2)} GB";
            else if (inst.CimInstanceProperties["AdapterRAM"]?.Value is uint adapterRam && adapterRam >= 1073741824u)
                vramStr = $"{Math.Round(adapterRam / 1073741824.0, 2)} GB";
            gpu.Add(($"{prefix}VRAM", vramStr));
            if (gpuIdx > 0) gpu.Add(("", ""));
            gpuIdx++;
        }

        ulong totalRam = 0;
        int slotIdx = 1;
        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT BankLabel, Capacity, Speed, PartNumber, Manufacturer FROM Win32_PhysicalMemory"))
        {
            var slot = inst.CimInstanceProperties["BankLabel"]?.Value?.ToString() ?? $"Slot {slotIdx}";
            var cap = inst.CimInstanceProperties["Capacity"]?.Value is ulong c ? c : 0UL;
            var speed = inst.CimInstanceProperties["Speed"]?.Value?.ToString() ?? "?";
            var part = inst.CimInstanceProperties["PartNumber"]?.Value?.ToString()?.Trim() ?? "Unknown";
            var mfr = inst.CimInstanceProperties["Manufacturer"]?.Value?.ToString()?.Trim() ?? "Unknown";
            totalRam += cap;
            var prefix = $"Slot {slotIdx} - ";
            ram.Add(($"{prefix}Slot", slot));
            ram.Add(($"{prefix}Capacity", $"{Math.Round(cap / 1073741824.0, 0)} GB"));
            ram.Add(($"{prefix}Speed", $"{speed} MT/s"));
            ram.Add(($"{prefix}Part Number", part));
            ram.Add(($"{prefix}Manufacturer", ResolveRamManufacturer(mfr, part)));
            slotIdx++;
        }
        if (totalRam > 0)
            ram.Add(("Total Installed", $"{Math.Round(totalRam / 1073741824.0, 0)} GB"));

        int diskIdx = 1;
        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT Model, Size, InterfaceType FROM Win32_DiskDrive"))
        {
            var model = inst.CimInstanceProperties["Model"]?.Value?.ToString() ?? "Unknown";
            var iface = inst.CimInstanceProperties["InterfaceType"]?.Value?.ToString() ?? "Unknown";
            var prefix = $"Disk {diskIdx} - ";
            storage.Add(($"{prefix}Model", model));
            if (inst.CimInstanceProperties["Size"]?.Value is ulong sz && sz > 0)
                storage.Add(($"{prefix}Size", $"{Math.Round(sz / 1073741824.0, 0)} GB"));
            storage.Add(($"{prefix}Interface", iface));
            diskIdx++;
        }

        try
        {
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT Name, Status FROM Win32_PnPEntity WHERE Name LIKE '%SMBus%'"))
            {
                chipset.Add(("Device", inst.CimInstanceProperties["Name"]?.Value?.ToString() ?? "Unknown"));
                chipset.Add(("Status", inst.CimInstanceProperties["Status"]?.Value?.ToString() ?? "Unknown"));
                break;
            }
        }
        catch (Exception ex)
        {
            LogManager.GetCurrentClassLogger().Debug(ex, "SMBus PnP query failed");
        }

        if (chipset.Count == 0) chipset.Add(("Status", "SMBus controller not found"));

        return (cpu, gpu, ram, storage, chipset);
    }

    private static Dictionary<string, long> ReadGpuVramFromRegistry()
    {
        var result = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
        try
        {
            const string classPath = @"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}";
            using var classKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(classPath);
            if (classKey is null) return result;
            foreach (var subName in classKey.GetSubKeyNames())
            {
                if (!int.TryParse(subName, out _)) continue;
                using var sub = classKey.OpenSubKey(subName);
                if (sub is null) continue;
                var adapterName = sub.GetValue("HardwareInformation.AdapterString") as string;
                var vramBytes = sub.GetValue("HardwareInformation.qwMemorySize") as byte[];
                if (adapterName is not null && vramBytes is { Length: >= 8 })
                    result[adapterName] = BitConverter.ToInt64(vramBytes, 0);
            }
        }
        catch (Exception ex)
        {
            LogManager.GetCurrentClassLogger().Debug(ex, "GPU VRAM registry read failed");
        }
        return result;
    }

    private static string ResolveRamManufacturer(string manufacturer, string partNumber)
    {
        if (!string.IsNullOrEmpty(manufacturer) && manufacturer != "Unknown" && manufacturer != " ")
            return manufacturer;
        return partNumber switch
        {
            var p when p.StartsWith("CM", StringComparison.Ordinal) => "Corsair",
            var p when p.StartsWith("CT", StringComparison.Ordinal) || p.StartsWith("BL", StringComparison.Ordinal) => "Crucial",
            var p when p.StartsWith("KVR", StringComparison.Ordinal) || p.StartsWith("HX", StringComparison.Ordinal) => "Kingston",
            var p when p.StartsWith("F4-", StringComparison.Ordinal) || p.StartsWith("F5-", StringComparison.Ordinal) => "G.Skill",
            var p when p.StartsWith("MTA", StringComparison.Ordinal) || p.StartsWith("MT", StringComparison.Ordinal) => "Micron",
            var p when p.StartsWith("M378", StringComparison.Ordinal) || p.StartsWith("M471", StringComparison.Ordinal) => "Samsung",
            var p when p.StartsWith("AD4", StringComparison.Ordinal) || p.StartsWith("AX4", StringComparison.Ordinal) => "ADATA",
            _ => "Unknown",
        };
    }

    private static void AppendSection(System.Text.StringBuilder sb, string title, List<(string Label, string Value)> rows)
    {
        sb.AppendLine(title);
        foreach (var (label, value) in rows)
            sb.AppendLine($"  {label,-22}: {value}");
        sb.AppendLine();
    }
}
