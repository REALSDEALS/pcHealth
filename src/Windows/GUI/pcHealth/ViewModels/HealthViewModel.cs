using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Management.Infrastructure;
using NLog;
using System.Diagnostics;
using System.Diagnostics.Eventing.Reader;
using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using System.Xml.Linq;
using Windows.Devices.Power;
using Windows.System.Power;

namespace pcHealth.ViewModels;

public partial class HealthViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    [ObservableProperty] public partial bool IsLoading { get; set; } = true;
    [ObservableProperty] public partial string ErrorMessage { get; set; } = "";

    public HealthData? Data { get; private set; }

    [RelayCommand]
    private async Task LoadAsync()
    {
        IsLoading = true;
        ErrorMessage = "";
        try
        {
            Log.Info("Health scan started");
            long started = Stopwatch.GetTimestamp();
            Data = await Task.Run(GatherData);
            Log.Info("Health scan finished in {Seconds:0.0}s",
                Stopwatch.GetElapsedTime(started).TotalSeconds);
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Health data gather failed");
            ErrorMessage = ex.Message;
        }
        finally
        {
            IsLoading = false;
        }
    }

    // --- Hardware DB ---

    private sealed class HardwareDb
    {
        [JsonPropertyName("gpu_series")] public List<GpuSeriesEntry> GpuSeries { get; init; } = [];
        [JsonPropertyName("gpu_models")] public List<GpuModelEntry> GpuModels { get; init; } = [];
        [JsonPropertyName("chipsets")] public List<ChipsetEntry> Chipsets { get; init; } = [];
    }

    private sealed class GpuSeriesEntry
    {
        [JsonPropertyName("pattern")] public string Pattern { get; init; } = "";
        [JsonPropertyName("vendor")] public string Vendor { get; init; } = "";
        [JsonPropertyName("series")] public string Series { get; init; } = "";
        [JsonPropertyName("year")] public int Year { get; init; }
    }

    private sealed class GpuModelEntry
    {
        [JsonPropertyName("name")] public string Name { get; init; } = "";
        [JsonPropertyName("year")] public int Year { get; init; }
    }

    private sealed class ChipsetEntry
    {
        [JsonPropertyName("pattern")] public string Pattern { get; init; } = "";
        [JsonPropertyName("vendor")] public string Vendor { get; init; } = "";
        [JsonPropertyName("name")] public string Name { get; init; } = "";
        [JsonPropertyName("platform")] public string Platform { get; init; } = "";
        [JsonPropertyName("year")] public int Year { get; init; }
        [JsonPropertyName("note")] public string? Note { get; init; }
    }

    private static HardwareDb? _hardwareDb;
    private static readonly object _dbLock = new();

    private static HardwareDb GetHardwareDb()
    {
        if (_hardwareDb != null) return _hardwareDb;
        lock (_dbLock)
        {
            if (_hardwareDb != null) return _hardwareDb;
            var path = Path.Combine(AppContext.BaseDirectory, "assets", "hardware-db.json");
            if (!File.Exists(path))
            {
                Log.Debug("hardware-db.json not found");
                return _hardwareDb = new HardwareDb();
            }
            try
            {
                var json = File.ReadAllText(path, System.Text.Encoding.UTF8);
                _hardwareDb = JsonSerializer.Deserialize<HardwareDb>(json) ?? new HardwareDb();
            }
            catch (Exception ex)
            {
                Log.Debug(ex, "hardware-db.json load failed");
                _hardwareDb = new HardwareDb();
            }
            return _hardwareDb;
        }
    }

    // --- Data gathering ---

    private static readonly Dictionary<string, DateTime> _winReleaseDates = new()
    {
        { "21H1", new DateTime(2021, 5,  18) },
        { "21H2", new DateTime(2021, 11, 16) },
        { "22H2", new DateTime(2022, 10, 18) },
        { "23H2", new DateTime(2023, 10, 31) },
        { "24H2", new DateTime(2024, 10,  1) },
        { "25H2", new DateTime(2025, 11,  1) },
        { "26H2", new DateTime(2026, 10,  1) },
    };

    /// <summary>
    /// Windows names a release YYHN and ships the first half around April and
    /// the second around October, so a version missing from the table above
    /// still dates to within a month or two. Without that fallback an old
    /// release reads as "Unknown" rather than as the dead version it is, and a
    /// version newer than this build of pcHealth reads the same way.
    /// </summary>
    private static DateTime? LookupWindowsRelease(string? displayVer)
    {
        if (string.IsNullOrEmpty(displayVer)) return null;
        if (_winReleaseDates.TryGetValue(displayVer, out var known)) return known;

        var m = Regex.Match(displayVer, @"^(\d{2})H([12])$");
        if (!m.Success) return null;

        int year = 2000 + int.Parse(m.Groups[1].Value);
        return new DateTime(year, m.Groups[2].Value == "1" ? 4 : 10, 1);
    }

    private static HealthData GatherData()
    {
        var legacyTask = Task.Run(GatherLegacyFeatures);
        var securityTask = Task.Run(static () => { using var s = CimSession.Create(null); return GatherSecurityInfo(s); });

        var cpu = new List<HealthRow>();
        var gpu = new List<GpuInfo>();
        var ram = new List<RamModule>();
        var diskSpace = new List<DriveRow>();
        var winVer = new List<HealthRow>();
        var boot = new List<HealthRow>();

        using var session = CimSession.Create(null);

        // Processor
        try
        {
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT Name FROM Win32_Processor"))
            {
                var name = inst.CimInstanceProperties["Name"]?.Value?.ToString()?.Trim() ?? "Unknown";
                cpu.Add(new HealthRow("Model", name, CheckStatus.Info));
                var (year, genLabel) = TryGetCpuReleaseYear(name);
                if (year > 0)
                {
                    int age = DateTime.Today.Year - year;
                    var s = age >= 10 ? CheckStatus.Bad : age >= 7 ? CheckStatus.Warning : CheckStatus.Good;
                    cpu.Add(new HealthRow("Generation", genLabel, CheckStatus.Info));
                    cpu.Add(new HealthRow("Release year", year.ToString(), s));
                }
                else
                {
                    cpu.Add(new HealthRow("Release year", "Unknown", CheckStatus.Unknown));
                }
                break;
            }
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "CPU query failed");
            cpu.Add(new HealthRow("CPU", "Query failed", CheckStatus.Unknown));
        }
        if (cpu.Count == 0)
            cpu.Add(new HealthRow("CPU", "Not found", CheckStatus.Unknown));

        // System model
        // An OEM board product is an internal code -- "HP 8B41" -- so the
        // machine model is the only name here a person can look up.
        try
        {
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT Manufacturer, Model FROM Win32_ComputerSystem"))
            {
                var sysMfr = (inst.CimInstanceProperties["Manufacturer"]?.Value?.ToString() ?? "").Trim();
                var sysModel = (inst.CimInstanceProperties["Model"]?.Value?.ToString() ?? "").Trim();
                if (sysModel.Length == 0) break;

                var display = sysMfr.Length == 0
                    || sysModel.StartsWith(sysMfr, StringComparison.OrdinalIgnoreCase)
                    ? sysModel : $"{sysMfr} {sysModel}";
                cpu.Add(new HealthRow("System", display, CheckStatus.Info));
                break;
            }
        }
        catch (Exception ex) { Log.Debug(ex, "ComputerSystem query failed"); }

        // Motherboard + Chipset
        bool chipsetNamed = false;
        try
        {
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT Manufacturer, Product FROM Win32_BaseBoard"))
            {
                var mfr = (inst.CimInstanceProperties["Manufacturer"]?.Value?.ToString() ?? "").Trim();
                var prod = (inst.CimInstanceProperties["Product"]?.Value?.ToString() ?? "").Trim();
                if (string.IsNullOrEmpty(prod)) break;

                var moboDisplay = (!string.IsNullOrEmpty(mfr)
                    && !prod.StartsWith(mfr, StringComparison.OrdinalIgnoreCase))
                    ? $"{mfr} {prod}" : prod;
                cpu.Add(new HealthRow("Motherboard", moboDisplay, CheckStatus.Info));

                var cs = LookupChipset(prod);
                if (cs.Name != null && cs.Year > 0)
                {
                    int age = DateTime.Today.Year - cs.Year;
                    var st = age >= 10 ? CheckStatus.Bad : age >= 7 ? CheckStatus.Warning : CheckStatus.Good;
                    var label = cs.Platform != null ? $"{cs.Name} ({cs.Platform})" : cs.Name;
                    cpu.Add(new HealthRow("Chipset", label, CheckStatus.Info));
                    cpu.Add(new HealthRow("Chipset release", cs.Year.ToString(), st));
                    chipsetNamed = true;
                }
                break;
            }
        }
        catch (Exception ex) { Log.Debug(ex, "BaseBoard query failed"); }

        // Chipset name + driver
        try
        {
            var (chipsetName, chipDate, chipVer) = GatherChipsetDriverInfo();
            if (!chipsetNamed && chipsetName != null)
                cpu.Add(new HealthRow("Chipset", chipsetName, CheckStatus.Info));

            // Intel's chipset INF ships DriverDate 7/18/1968 so that any real
            // driver outranks it. It is a sorting key, not a release date, and
            // calling it two decades stale is simply wrong.
            if (chipDate.HasValue && chipDate.Value.Year >= 2001)
            {
                int months = (int)((DateTime.Today - chipDate.Value).TotalDays / 30.44);
                var s = months > 24 ? CheckStatus.Warning : CheckStatus.Good;
                cpu.Add(new HealthRow("Chipset driver", chipDate.Value.ToString("yyyy-MM-dd"), s));
            }

            if (chipVer != null)
                cpu.Add(new HealthRow("Chipset version", chipVer, CheckStatus.Info));
        }
        catch (Exception ex) { Log.Debug(ex, "Chipset driver info failed"); }

        // Graphics
        try
        {
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT Name, DriverDate FROM Win32_VideoController"))
            {
                var name = inst.CimInstanceProperties["Name"]?.Value?.ToString()?.Trim() ?? "Unknown";
                int? driverMonths = null;
                if (inst.CimInstanceProperties["DriverDate"]?.Value is DateTime dd)
                    driverMonths = (int)((DateTime.Today - dd).TotalDays / 30.44);

                var (releaseYear, seriesName) = LookupGpuYear(name);
                gpu.Add(new GpuInfo(name, driverMonths, releaseYear, seriesName));
            }
            if (gpu.Count == 0)
                gpu.Add(new GpuInfo("Not found", null, null, null));
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "GPU query failed");
            gpu.Add(new GpuInfo("Query failed", null, null, null));
        }

        // RAM
        try
        {
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT BankLabel, Capacity, Speed, ConfiguredClockSpeed, SMBIOSMemoryType, PartNumber, Manufacturer FROM Win32_PhysicalMemory"))
            {
                var slot = inst.CimInstanceProperties["BankLabel"]?.Value?.ToString()?.Trim() ?? "?";
                var capRaw = inst.CimInstanceProperties["Capacity"]?.Value;
                double capGb = capRaw is ulong ul ? ul / 1_073_741_824.0
                             : capRaw is uint u ? u / 1_073_741_824.0 : 0;

                var cfgRaw = inst.CimInstanceProperties["ConfiguredClockSpeed"]?.Value;
                int speed = cfgRaw is uint cu ? (int)cu : cfgRaw is int ci ? ci : 0;
                if (speed <= 0)
                {
                    var spdRaw = inst.CimInstanceProperties["Speed"]?.Value;
                    speed = spdRaw is uint su ? (int)su : spdRaw is int si ? si : 0;
                }

                var mtRaw = inst.CimInstanceProperties["SMBIOSMemoryType"]?.Value;
                int memType = mtRaw is ushort us ? us : mtRaw is uint um ? (int)um : 0;

                var pn = inst.CimInstanceProperties["PartNumber"]?.Value?.ToString()?.Trim() ?? "";
                var mfr = inst.CimInstanceProperties["Manufacturer"]?.Value?.ToString()?.Trim() ?? "";
                ram.Add(new RamModule(slot, capGb, speed, memType, pn, ResolveRamManufacturer(mfr, pn)));
            }
        }
        catch (Exception ex) { Log.Debug(ex, "RAM query failed"); }

        // SMART
        var smartctlPath = FindSmartctl();
        List<DiskHealthInfo> smart;
        bool usedSmartctl;
        if (smartctlPath != null)
        {
            smart = GatherSmartViaSmartctl(smartctlPath);
            usedSmartctl = true;
        }
        else
        {
            smart = GatherSmartViaCim(session);
            usedSmartctl = false;
        }

        // Disk space
        try
        {
            foreach (var drive in DriveInfo.GetDrives()
                .Where(d => d.DriveType == DriveType.Fixed && d.IsReady))
            {
                long total = drive.TotalSize;
                long free = drive.AvailableFreeSpace;
                long used = total - free;
                double pct = total > 0 ? (double)used / total * 100 : 0;
                var s = pct > 90 ? CheckStatus.Bad : pct > 75 ? CheckStatus.Warning : CheckStatus.Good;
                diskSpace.Add(new DriveRow(drive.Name.TrimEnd('\\'), used, total, s));
            }
        }
        catch (Exception ex) { Log.Debug(ex, "Disk space failed"); }

        // Windows version
        try
        {
            using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
                @"SOFTWARE\Microsoft\Windows NT\CurrentVersion");
            var displayVer = key?.GetValue("DisplayVersion") as string;
            var buildStr = key?.GetValue("CurrentBuild") as string;
            bool isWin11 = int.TryParse(buildStr, out int build) && build >= 22000;
            var edition = isWin11 ? "Windows 11" : "Windows 10";

            winVer.Add(new HealthRow("Version",
                string.IsNullOrEmpty(displayVer) ? edition : $"{edition} {displayVer}",
                CheckStatus.Info));

            var released = LookupWindowsRelease(displayVer);
            if (released.HasValue)
            {
                int months = (int)((DateTime.Today - released.Value).TotalDays / 30.44);
                var s = months > 24 ? CheckStatus.Bad : months > 18 ? CheckStatus.Warning : CheckStatus.Good;
                winVer.Add(new HealthRow("Released", released.Value.ToString("MMM yyyy"), s));
            }
            else if (!string.IsNullOrEmpty(displayVer))
            {
                winVer.Add(new HealthRow("Released", "Unknown", CheckStatus.Unknown));
            }
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "Windows version failed");
            winVer.Add(new HealthRow("Version", "Query failed", CheckStatus.Unknown));
        }

        // Boot performance
        try
        {
            var query = new EventLogQuery(
                "Microsoft-Windows-Diagnostics-Performance/Operational",
                PathType.LogName, "*[System/EventID=100]")
            { ReverseDirection = true };

            using var reader = new EventLogReader(query);
            if (reader.ReadEvent() is { } rec)
            {
                XNamespace ns = "http://schemas.microsoft.com/win/2004/08/events/event"; // DevSkim: ignore DS137138
                var map = XDocument.Parse(rec.ToXml())
                    .Descendants(ns + "Data")
                    .Where(d => d.Attribute("Name") != null)
                    .ToDictionary(d => d.Attribute("Name")!.Value, d => d.Value);

                long? fwMs = TryGetLongMs(map, "FirmwareDuration", "FirmwareBootTime");
                if (fwMs.HasValue)
                {
                    double s = fwMs.Value / 1000.0;
                    var st = s > 30 ? CheckStatus.Bad : s > 10 ? CheckStatus.Warning : CheckStatus.Good;
                    boot.Add(new HealthRow("UEFI/firmware time",
                        s.ToString("F1", CultureInfo.InvariantCulture) + "s", st));
                }

                long? bdMs = TryGetLongMs(map, "BootDuration", "BootTime", "TotalBootTime", "MainPathBootTime");
                if (bdMs.HasValue)
                {
                    double s = bdMs.Value / 1000.0;
                    var st = s > 120 ? CheckStatus.Bad : s > 60 ? CheckStatus.Warning : CheckStatus.Good;
                    boot.Add(new HealthRow("Total boot time",
                        s.ToString("F1", CultureInfo.InvariantCulture) + "s", st));
                }
                rec.Dispose();
            }
        }
        catch (Exception ex) { Log.Debug(ex, "Boot event log failed"); }

        var uptime = TimeSpan.FromMilliseconds(Environment.TickCount64);
        boot.Add(new HealthRow("System uptime",
            uptime.TotalDays >= 1
                ? $"{(int)uptime.TotalDays}d {uptime.Hours}h {uptime.Minutes}m"
                : $"{uptime.Hours}h {uptime.Minutes}m",
            CheckStatus.Info));

        try
        {
            int count = 0;
            foreach (var _ in session.QueryInstances("root/cimv2", "WQL",
                "SELECT Name FROM Win32_StartupCommand"))
                count++;
            var s = count > 20 ? CheckStatus.Bad : count > 12 ? CheckStatus.Warning : CheckStatus.Good;
            boot.Add(new HealthRow("Startup programs", count.ToString(), s));
        }
        catch (Exception ex) { Log.Debug(ex, "Startup programs failed"); }

        var battery = GatherBatteryInfo(session);

        var security = securityTask.GetAwaiter().GetResult();
        var legacyFeatures = legacyTask.GetAwaiter().GetResult();

        return new HealthData(cpu, gpu, ram, smart, usedSmartctl, diskSpace, winVer, boot, battery, security, legacyFeatures);
    }

    // --- Hardware DB lookups ---

    private static (int? year, string? seriesName) LookupGpuYear(string gpuName)
    {
        var db = GetHardwareDb();

        foreach (var model in db.GpuModels)
            if (gpuName.Contains(model.Name, StringComparison.OrdinalIgnoreCase))
                return (model.Year, null);

        foreach (var series in db.GpuSeries)
            if (gpuName.Contains(series.Pattern, StringComparison.OrdinalIgnoreCase))
                return (series.Year, series.Series);

        var fallback = TryGetGpuReleaseYearRegex(gpuName);
        return (fallback, null);
    }

    private static (string? Name, string? Platform, int Year, string? Note) LookupChipset(string moboProduct)
    {
        var db = GetHardwareDb();
        foreach (var cs in db.Chipsets)
        {
            int idx = moboProduct.IndexOf(cs.Pattern, StringComparison.OrdinalIgnoreCase);
            if (idx < 0) continue;
            int after = idx + cs.Pattern.Length;
            if (after < moboProduct.Length && char.IsDigit(moboProduct[after])) continue;
            return (cs.Name, cs.Platform, cs.Year, cs.Note);
        }
        return (null, null, 0, null);
    }

    /// <summary>
    /// Walks the System device class once for both the chipset name and the
    /// chipset driver, which live on two different devices in it.
    /// </summary>
    private static (string? chipset, DateTime? driverDate, string? driverVersion) GatherChipsetDriverInfo()
    {
        const string classKey = @"SYSTEM\CurrentControlSet\Control\Class\{4D36E97D-E325-11CE-BFC1-08002BE10318}";
        using var cls = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(classKey);
        if (cls == null) return (null, null, null);

        string? chipset = null;
        DateTime? driverDate = null;
        string? driverVersion = null;
        bool haveDriver = false;

        foreach (var subName in cls.GetSubKeyNames())
        {
            if (!int.TryParse(subName, out _)) continue;
            using var sub = cls.OpenSubKey(subName);
            if (sub == null) continue;

            var desc = sub.GetValue("DriverDesc") as string ?? "";

            // The LPC/eSPI controller is the device whose name carries the
            // chipset family. An OEM board product -- "HP 8B41", "Dell 0K1N2M"
            // -- never does, so without this those machines show no chipset.
            if (chipset == null && desc.Contains("LPC", StringComparison.OrdinalIgnoreCase))
                chipset = CleanChipsetName(desc);

            if (!haveDriver && desc.Contains("SMBus", StringComparison.OrdinalIgnoreCase))
            {
                haveDriver = true;
                driverVersion = sub.GetValue("DriverVersion") as string;
                if (sub.GetValue("DriverDate") is string dateStr
                    && DateTime.TryParse(dateStr, CultureInfo.InvariantCulture, DateTimeStyles.None, out var dt))
                    driverDate = dt;
            }

            if (chipset != null && haveDriver) break;
        }
        return (chipset, driverDate, driverVersion);
    }

    /// <summary>
    /// "Intel(R) Raptor Lake-P LPC Controller - 519D" becomes "Intel Raptor
    /// Lake-P"; the PCI device id and the role are noise on a health page.
    /// </summary>
    private static string? CleanChipsetName(string desc)
    {
        var s = StripTrademarks(desc);
        s = Regex.Replace(s, @"\s*-\s*[0-9A-F]{4}\s*$", "", RegexOptions.IgnoreCase);
        s = Regex.Replace(s, @"\s*LPC(?:/eSPI)?\s*(?:Controller|Interface)?", " ", RegexOptions.IgnoreCase);
        s = Regex.Replace(s, @"\s+", " ").Trim();

        // A vendor on its own ("Intel", from a plain "Intel(R) LPC Controller")
        // says nothing, and a paragraph is not a name either.
        bool named = s.Length < 60 && s.Contains(' ');
        return named ? s : null;
    }

    // --- smartctl helpers ---

    private static string? FindSmartctl()
    {
        var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        var known = Path.Combine(pf, "smartmontools", "bin", "smartctl.exe");
        if (File.Exists(known)) return known;

        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator))
        {
            var c = Path.Combine(dir.Trim(), "smartctl.exe");
            if (File.Exists(c)) return c;
        }
        return null;
    }

    private static string? RunCapture(string exe, string args)
    {
        try
        {
            using var proc = new Process();
            proc.StartInfo = new ProcessStartInfo
            {
                FileName = exe,
                Arguments = args,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
            };

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
            proc.Start();
            var stderrTask = proc.StandardError.ReadToEndAsync(cts.Token);
            string output;
            try
            {
                output = proc.StandardOutput.ReadToEndAsync(cts.Token).GetAwaiter().GetResult();
            }
            catch (OperationCanceledException)
            {
                proc.Kill(entireProcessTree: true);
                Log.Debug("RunCapture '{Exe} {Args}' timed out after 30s", exe, args);
                return null;
            }
            try { stderrTask.GetAwaiter().GetResult(); }
            catch (Exception ex) { Log.Debug(ex, "RunCapture stderr drain failed"); }
            proc.WaitForExit();
            return output;
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "RunCapture '{Exe} {Args}' failed", exe, args);
            return null;
        }
    }

    private static string? RunCaptureWithArgs(string exe, string devicePath, IReadOnlyList<string> extraArgs)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = exe,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
            };
            foreach (var arg in extraArgs)
                psi.ArgumentList.Add(arg);
            psi.ArgumentList.Add(devicePath);

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
            using var proc = new Process { StartInfo = psi };
            proc.Start();
            var stderrTask = proc.StandardError.ReadToEndAsync(cts.Token);
            string output;
            try
            {
                output = proc.StandardOutput.ReadToEndAsync(cts.Token).GetAwaiter().GetResult();
            }
            catch (OperationCanceledException)
            {
                proc.Kill(entireProcessTree: true);
                Log.Debug("RunCaptureWithArgs '{Exe} {Device}' timed out after 30s", exe, devicePath);
                return null;
            }
            try { stderrTask.GetAwaiter().GetResult(); }
            catch (Exception ex) { Log.Debug(ex, "RunCaptureWithArgs stderr drain failed"); }
            proc.WaitForExit();
            return output;
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "RunCaptureWithArgs '{Exe} {Device}' failed", exe, devicePath);
            return null;
        }
    }

    private static List<DiskHealthInfo> GatherSmartViaSmartctl(string smartctlPath)
    {
        var result = new List<DiskHealthInfo>();
        try
        {
            var scanJson = RunCapture(smartctlPath, "--scan --json");
            if (string.IsNullOrWhiteSpace(scanJson)) return result;

            using var scanDoc = JsonDocument.Parse(scanJson);
            if (!scanDoc.RootElement.TryGetProperty("devices", out var devices)) return result;

            foreach (var dev in devices.EnumerateArray())
            {
                var devName = dev.TryGetProperty("name", out var n) ? n.GetString() : null;
                var devType = dev.TryGetProperty("type", out var t) ? t.GetString() : null;
                if (string.IsNullOrEmpty(devName)) continue;

                var scanArgs = (!string.IsNullOrEmpty(devType) && devType != "auto")
                    ? new List<string> { "-a", "-d", devType, "--json" }
                    : new List<string> { "-a", "--json" };

                var dataJson = RunCaptureWithArgs(smartctlPath, devName!, scanArgs);
                if (string.IsNullOrWhiteSpace(dataJson)) continue;

                using var dataDoc = JsonDocument.Parse(dataJson);
                var root = dataDoc.RootElement;

                var model = root.TryGetProperty("model_name", out var mn)
                    ? mn.GetString() ?? devName : devName;

                bool? passed = null;
                if (root.TryGetProperty("smart_status", out var ss) && ss.TryGetProperty("passed", out var p))
                    passed = p.ValueKind == JsonValueKind.True ? true
                           : p.ValueKind == JsonValueKind.False ? false : (bool?)null;
                var (healthText, healthStatus) = passed switch
                {
                    true => ("Healthy", CheckStatus.Good),
                    false => ("FAILING", CheckStatus.Bad),
                    _ => ("Unknown", CheckStatus.Unknown),
                };

                byte? wear = null;
                if (root.TryGetProperty("nvme_smart_health_information_log", out var nvmeLog)
                    && nvmeLog.TryGetProperty("percentage_used", out var pu))
                {
                    wear = (byte)Math.Min(100, Math.Max(0, pu.GetInt32()));
                }
                else if (root.TryGetProperty("ata_smart_attributes", out var ata)
                    && ata.TryGetProperty("table", out var table))
                {
                    foreach (var attr in table.EnumerateArray())
                    {
                        if (!attr.TryGetProperty("id", out var idEl)) continue;
                        if (idEl.GetInt32() is 231 or 202 or 177
                            && attr.TryGetProperty("value", out var val))
                        {
                            wear = (byte)(100 - Math.Min(100, Math.Max(0, val.GetInt32())));
                            break;
                        }
                    }
                }

                ushort? temp = null;
                if (root.TryGetProperty("temperature", out var tempNode)
                    && tempNode.TryGetProperty("current", out var tc))
                    temp = (ushort)tc.GetInt32();

                ulong? poh = null;
                if (root.TryGetProperty("power_on_time", out var pot)
                    && pot.TryGetProperty("hours", out var h))
                    poh = (ulong)h.GetInt64();

                ulong? tbwGb = null;
                if (root.TryGetProperty("nvme_smart_health_information_log", out var nvmeLog2)
                    && nvmeLog2.TryGetProperty("data_units_written", out var duw))
                {
                    tbwGb = (ulong)duw.GetInt64() * 512000UL / 1_000_000_000UL;
                }
                else if (root.TryGetProperty("ata_smart_attributes", out var ata2)
                    && ata2.TryGetProperty("table", out var table2))
                {
                    foreach (var attr in table2.EnumerateArray())
                    {
                        if (!attr.TryGetProperty("id", out var idEl)) continue;
                        if (idEl.GetInt32() is 241 or 246
                            && attr.TryGetProperty("raw", out var raw)
                            && raw.TryGetProperty("value", out var rawVal))
                        {
                            tbwGb = (ulong)rawVal.GetInt64() * 512UL / 1_000_000_000UL;
                            break;
                        }
                    }
                }

                int rotRate = root.TryGetProperty("rotation_rate", out var rr) ? rr.GetInt32() : 0;
                var mediaType = devType == "nvme" ? "NVMe SSD"
                    : rotRate > 0 ? "HDD" : "SATA SSD";

                string? speedFlag = null;
                if (devType == "sat")
                {
                    speedFlag = rotRate > 0
                        ? "HDD - mechanical, much slower than SSD"
                        : "SATA - significantly slower than NVMe, consider upgrading";
                }
                else if (devType == "nvme"
                    && root.TryGetProperty("nvme_pcie_link_info", out var pcie)
                    && pcie.TryGetProperty("current_speed", out var cs))
                {
                    var speedStr = cs.GetString() ?? "";
                    if (double.TryParse(speedStr.Replace(" GT/s", ""),
                        NumberStyles.Any, CultureInfo.InvariantCulture, out double gts))
                    {
                        if (gts <= 5.0)
                            speedFlag = "PCIe Gen 1 - old interface, consider upgrading";
                        else if (gts <= 8.0)
                            speedFlag = "PCIe Gen 2 - older interface, consider upgrading";
                    }
                }

                result.Add(new DiskHealthInfo(model!, mediaType, healthStatus, healthText,
                    wear, temp, poh, speedFlag, tbwGb));
            }
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "smartctl parsing failed");
        }
        return result;
    }

    private static List<DiskHealthInfo> GatherSmartViaCim(CimSession session)
    {
        var result = new List<DiskHealthInfo>();

        var relMap = new Dictionary<string, (byte? wear, ushort? temp, ulong? poh)>(
            StringComparer.OrdinalIgnoreCase);
        try
        {
            foreach (var rel in session.QueryInstances("root/Microsoft/Windows/Storage", "WQL",
                "SELECT DeviceId, Wear, Temperature, PowerOnHours FROM MSFT_StorageReliabilityCounter"))
            {
                var rid = rel.CimInstanceProperties["DeviceId"]?.Value?.ToString() ?? "";
                var w = rel.CimInstanceProperties["Wear"]?.Value as byte?;
                var rt = rel.CimInstanceProperties["Temperature"]?.Value;
                var t = rt is ushort us ? us : rt is byte bt ? (ushort?)bt : null;
                var rp = rel.CimInstanceProperties["PowerOnHours"]?.Value;
                var p = rp is ulong ul ? ul : rp is uint ui ? (ulong?)ui : null;
                relMap[rid] = (w, t, p);
            }
        }
        catch (Exception ex) { Log.Debug(ex, "ReliabilityCounter failed"); }

        try
        {
            bool any = false;
            foreach (var disk in session.QueryInstances("root/Microsoft/Windows/Storage", "WQL",
                "SELECT DeviceId, FriendlyName, HealthStatus, MediaType, BusType FROM MSFT_PhysicalDisk"))
            {
                var name = disk.CimInstanceProperties["FriendlyName"]?.Value?.ToString() ?? "Unknown";
                var deviceId = disk.CimInstanceProperties["DeviceId"]?.Value?.ToString() ?? "";

                var rawHealth = disk.CimInstanceProperties["HealthStatus"]?.Value;
                int hs = rawHealth is ushort ush ? ush : rawHealth is uint u2 ? (int)u2
                       : rawHealth is int i2 ? i2 : -1;
                var (healthText, healthStatus) = hs switch
                {
                    0 => ("Healthy", CheckStatus.Good),
                    1 => ("Warning", CheckStatus.Warning),
                    2 => ("Unhealthy", CheckStatus.Bad),
                    _ => ("Unknown", CheckStatus.Unknown),
                };

                var rawMedia = disk.CimInstanceProperties["MediaType"]?.Value;
                int mt = rawMedia is ushort umt ? umt : rawMedia is uint umu ? (int)umu : 0;
                var rawBus = disk.CimInstanceProperties["BusType"]?.Value;
                int bt = rawBus is ushort ubt ? ubt : rawBus is uint ubu ? (int)ubu : 0;

                var mediaType = (bt, mt) switch
                {
                    (17, _) => "NVMe SSD",
                    (11, 4) => "SATA SSD",
                    (_, 3) => "HDD",
                    (11, _) => "SATA",
                    _ => mt == 4 ? "SSD" : "Disk",
                };

                string? speedFlag = (bt, mt) switch
                {
                    (11, 4) => "SATA SSD - significantly slower than NVMe, consider upgrading",
                    (11, 3) => "SATA HDD - mechanical, much slower than SSD",
                    (_, 3) => "HDD - mechanical, much slower than SSD",
                    (3, _) => "ATA - very old interface",
                    _ => null,
                };

                relMap.TryGetValue(deviceId, out var rc);
                result.Add(new DiskHealthInfo(name, mediaType, healthStatus, healthText,
                    rc.wear, rc.temp, rc.poh, speedFlag, null));
                any = true;
            }
            if (!any)
                result.Add(new DiskHealthInfo("No physical disks found", "", CheckStatus.Unknown, "N/A", null, null, null, null, null));
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "SMART CIM failed");
            result.Add(new DiskHealthInfo("Query failed", "", CheckStatus.Unknown, ex.Message, null, null, null, null, null));
        }
        return result;
    }

    // --- Battery helpers ---

    private static BatteryInfo? GatherBatteryInfo(CimSession session)
    {
        string? name = null;
        string? chemistry = null;
        int? estimatedRuntimeMin = null;
        int? cycleCount = null;
        bool cycleCountQueried = false;

        try
        {
            bool found = false;
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT Name, Chemistry, EstimatedRunTime FROM Win32_Battery"))
            {
                found = true;
                name = inst.CimInstanceProperties["Name"]?.Value?.ToString()?.Trim();
                if (inst.CimInstanceProperties["Chemistry"]?.Value is ushort chem)
                    chemistry = DecodeBatteryChemistry(chem);
                if (inst.CimInstanceProperties["EstimatedRunTime"]?.Value is uint rt && rt < 71582)
                    estimatedRuntimeMin = (int)rt;
                break;
            }
            if (!found) return null;
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "Battery CIM failed");
            return null;
        }

        try
        {
            foreach (var inst in session.QueryInstances("root/WMI", "WQL",
                "SELECT CycleCount FROM BatteryCycleCount"))
            {
                cycleCountQueried = true;
                var cc = inst.CimInstanceProperties["CycleCount"]?.Value;
                cycleCount = cc is uint u ? (int)u : cc is int i ? i : (int?)null;
                break;
            }
            if (!cycleCountQueried) cycleCountQueried = true;
        }
        catch (Exception ex) { Log.Debug(ex, "BatteryCycleCount WMI failed"); }

        var batteryAgeMonths = TryGetBatteryAgeMonths(session);

        try
        {
            var report = Battery.AggregateBattery.GetReport();
            if (report.Status == BatteryStatus.NotPresent) return null;

            var statusText = report.Status switch
            {
                BatteryStatus.Charging => "Charging",
                BatteryStatus.Discharging => "Discharging",
                BatteryStatus.Idle => "Idle",
                _ => "Unknown",
            };

            return new BatteryInfo(
                name, chemistry,
                report.DesignCapacityInMilliwattHours,
                report.FullChargeCapacityInMilliwattHours,
                report.RemainingCapacityInMilliwattHours,
                report.ChargeRateInMilliwatts,
                statusText,
                estimatedRuntimeMin,
                cycleCount, cycleCountQueried,
                batteryAgeMonths
            );
        }
        catch (Exception ex) { Log.Debug(ex, "Battery WinRT API failed"); }

        return new BatteryInfo(name, chemistry, null, null, null, null, "Unknown",
            estimatedRuntimeMin, cycleCount, cycleCountQueried, batteryAgeMonths);
    }

    /// <summary>
    /// How old the battery is in months, or null when nothing reports a date.
    /// </summary>
    /// <remarks>
    /// Two sources, because neither is dependable alone. BatteryStaticData is
    /// the ACPI provider in root/WMI, which a lot of OEM firmware answers with
    /// "Generic failure" rather than implementing -- that is routine, not a
    /// fault, so it is noted without a stack trace. Win32_PortableBattery is
    /// the SMBIOS view of the same battery and needs no ACPI provider, though
    /// not every firmware fills the date in there either.
    /// </remarks>
    private static int? TryGetBatteryAgeMonths(CimSession session)
    {
        try
        {
            foreach (var inst in session.QueryInstances("root/WMI", "WQL",
                "SELECT ManufactureDate FROM BatteryStaticData"))
            {
                var raw = inst.CimInstanceProperties["ManufactureDate"]?.Value;
                uint packed = raw is uint u ? u : raw is ushort us ? (uint)us : 0;
                var date = DecodeSbdsDate(packed);
                if (date.HasValue) return MonthsSince(date.Value);
                break;
            }
        }
        catch (CimException ex)
        {
            Log.Debug("BatteryStaticData unavailable: {Message}", ex.Message);
        }

        try
        {
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT ManufactureDate FROM Win32_PortableBattery"))
            {
                if (inst.CimInstanceProperties["ManufactureDate"]?.Value is DateTime mfg)
                    return MonthsSince(mfg);
                break;
            }
        }
        catch (CimException ex)
        {
            Log.Debug("Win32_PortableBattery unavailable: {Message}", ex.Message);
        }

        return null;
    }

    /// <summary>
    /// The Smart Battery Data spec packs the date into sixteen bits: day in
    /// the low five, month in the next four, year since 1980 in the top seven.
    /// </summary>
    private static DateTime? DecodeSbdsDate(uint packed)
    {
        if (packed == 0) return null;

        int day = (int)(packed & 0x1F);
        int month = (int)((packed >> 5) & 0x0F);
        int year = (int)((packed >> 9) & 0x7F) + 1980;

        // A garbage word decodes to a garbage date, and the 31st of a 30-day
        // month throws rather than returning something wrong.
        if (month is < 1 or > 12 || day < 1 || year < 2000) return null;
        if (day > DateTime.DaysInMonth(year, month)) return null;

        return new DateTime(year, month, day);
    }

    private static int MonthsSince(DateTime date) =>
        (int)((DateTime.Today - date).TotalDays / 30.44);

    private static string DecodeBatteryChemistry(ushort code) => code switch
    {
        3 => "Lead Acid",
        4 => "Nickel Cadmium",
        5 => "Nickel Metal Hydride",
        6 => "Lithium-ion",
        7 => "Zinc Air",
        8 => "Lithium Polymer",
        _ => "Unknown",
    };

    // --- Security gathering ---

    private static SecurityInfo GatherSecurityInfo(CimSession session)
    {
        var defender = new List<HealthRow>();
        var bitlocker = new List<HealthRow>();
        var secureBoot = new List<HealthRow>();
        var tpm = new List<HealthRow>();

        bool hasActiveThirdPartyAv = false;
        try
        {
            foreach (var inst in session.QueryInstances(
                @"ROOT\SecurityCenter2", "WQL",
                "SELECT displayName, productState FROM AntiVirusProduct"))
            {
                var avName = inst.CimInstanceProperties["displayName"]?.Value?.ToString()?.Trim() ?? "Unknown";
                var psRaw = inst.CimInstanceProperties["productState"]?.Value;
                uint ps = psRaw is uint u ? u : 0;
                bool avActive = (ps & 0x1000) != 0 && (ps & 0x0100) == 0;
                bool isDefender = avName.StartsWith("Windows Defender", StringComparison.OrdinalIgnoreCase)
                               || avName.StartsWith("Microsoft Defender", StringComparison.OrdinalIgnoreCase)
                               || avName.Equals("Windows Security", StringComparison.OrdinalIgnoreCase);
                if (!isDefender)
                {
                    if (avActive) hasActiveThirdPartyAv = true;
                    defender.Add(new HealthRow("Registered AV", avName, avActive ? CheckStatus.Good : CheckStatus.Info));
                }
            }
        }
        catch (Exception ex) { Log.Debug(ex, "SecurityCenter2 query failed"); }

        try
        {
            foreach (var inst in session.QueryInstances(
                @"root\Microsoft\Windows\Defender", "WQL",
                "SELECT AMServiceEnabled, RealTimeProtectionEnabled, AntivirusEnabled, AntispywareEnabled FROM MSFT_MpComputerStatus"))
            {
                bool svc = inst.CimInstanceProperties["AMServiceEnabled"]?.Value is bool b1 && b1;
                bool rt = inst.CimInstanceProperties["RealTimeProtectionEnabled"]?.Value is bool b2 && b2;
                bool av = inst.CimInstanceProperties["AntivirusEnabled"]?.Value is bool b3 && b3;
                bool asp = inst.CimInstanceProperties["AntispywareEnabled"]?.Value is bool b4 && b4;
                var off = hasActiveThirdPartyAv ? CheckStatus.Info : CheckStatus.Bad;
                var rtLabel = rt ? "Enabled" : hasActiveThirdPartyAv ? "Disabled (passive mode)" : "Disabled";
                defender.Add(new HealthRow("Defender Service", svc ? "Running" : "Stopped", svc ? CheckStatus.Good : off));
                defender.Add(new HealthRow("Real-time Protection", rtLabel, rt ? CheckStatus.Good : off));
                defender.Add(new HealthRow("Antivirus", av ? "Enabled" : "Disabled", av ? CheckStatus.Good : off));
                defender.Add(new HealthRow("Antispyware", asp ? "Enabled" : "Disabled", asp ? CheckStatus.Good : off));
                break;
            }
        }
        catch (Exception ex) { Log.Debug(ex, "Defender query failed"); }
        if (defender.Count == 0) defender.Add(new HealthRow("Status", "Not available", CheckStatus.Unknown));

        try
        {
            bool any = false;
            foreach (var inst in session.QueryInstances(
                @"ROOT\cimv2\Security\MicrosoftVolumeEncryption", "WQL",
                "SELECT DriveLetter, ProtectionStatus FROM Win32_EncryptableVolume"))
            {
                var drive = inst.CimInstanceProperties["DriveLetter"]?.Value?.ToString() ?? "?";
                var raw = inst.CimInstanceProperties["ProtectionStatus"]?.Value;
                int ps = raw is uint u ? (int)u : raw is int i ? i : -1;
                var (label, status) = ps switch
                {
                    1 => ("Encrypted", CheckStatus.Good),
                    0 => ("Not encrypted", CheckStatus.Warning),
                    _ => ("Unknown", CheckStatus.Unknown),
                };
                bitlocker.Add(new HealthRow(drive, label, status));
                any = true;
            }
            if (!any) bitlocker.Add(new HealthRow("Status", "No encryptable drives found", CheckStatus.Unknown));
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "BitLocker query failed");
            bitlocker.Add(new HealthRow("Status", "Query failed (requires elevation)", CheckStatus.Unknown));
        }

        try
        {
            using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
                @"SYSTEM\CurrentControlSet\Control\SecureBoot\State");
            bool on = key?.GetValue("UEFISecureBootEnabled") is int v && v == 1;
            secureBoot.Add(new HealthRow("Secure Boot", on ? "Enabled" : "Disabled",
                on ? CheckStatus.Good : CheckStatus.Warning));
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "Secure Boot registry failed");
            secureBoot.Add(new HealthRow("Secure Boot", "N/A (legacy BIOS?)", CheckStatus.Unknown));
        }

        try
        {
            bool found = false;
            foreach (var inst in session.QueryInstances(
                "root/cimv2/security/microsofttpm", "WQL",
                "SELECT IsActivated_InitialValue, IsEnabled_InitialValue, SpecVersion FROM Win32_Tpm"))
            {
                bool activated = inst.CimInstanceProperties["IsActivated_InitialValue"]?.Value is bool a && a;
                bool enabled = inst.CimInstanceProperties["IsEnabled_InitialValue"]?.Value is bool en && en;
                var spec = inst.CimInstanceProperties["SpecVersion"]?.Value?.ToString();
                var version = !string.IsNullOrEmpty(spec) ? spec.Split(',')[0].Trim() : "Unknown";
                tpm.Add(new HealthRow("Version", version, version != "Unknown" ? CheckStatus.Good : CheckStatus.Unknown));
                tpm.Add(new HealthRow("Enabled", enabled ? "Yes" : "No", enabled ? CheckStatus.Good : CheckStatus.Bad));
                tpm.Add(new HealthRow("Activated", activated ? "Yes" : "No", activated ? CheckStatus.Good : CheckStatus.Bad));
                found = true;
                break;
            }
            if (!found) tpm.Add(new HealthRow("Status", "TPM not found or not accessible", CheckStatus.Bad));
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "TPM query failed");
            tpm.Add(new HealthRow("Status", "Query failed", CheckStatus.Unknown));
        }

        return new SecurityInfo(defender, bitlocker, secureBoot, tpm);
    }

    // --- Legacy features ---

    private static List<HealthRow> GatherLegacyFeatures()
    {
        var rows = new List<HealthRow>();

        try
        {
            using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
                @"SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters");
            var val = key?.GetValue("SMB1");
            bool smb1 = val is int i && i != 0;
            rows.Add(new HealthRow("SMBv1 Protocol",
                smb1 ? "Enabled - disable immediately" : "Disabled",
                smb1 ? CheckStatus.Bad : CheckStatus.Good));
        }
        catch (Exception ex) { Log.Debug(ex, "SMBv1 registry failed"); }

        // VBScript is not here on purpose: it is a capability, not an optional
        // feature, so asking this class for it always answered "absent".
        var featureMap = new Dictionary<string, (string Label, bool IsCritical)>(StringComparer.OrdinalIgnoreCase)
        {
            ["WindowsMediaPlayer"] = ("Legacy Windows Media Player", false),
            ["MicrosoftWindowsPowerShellV2Root"] = ("PowerShell v2", false),
            ["TelnetClient"] = ("Telnet Client", false),
            ["TFTP"] = ("TFTP Client", false),
            ["DirectPlay"] = ("DirectPlay", false),
            ["WorkFolders-Client"] = ("Work Folders Client", false),
        };

        // Win32_OptionalFeature reports the state DISM does, over the same
        // servicing stack, in one query. Asking dism.exe instead meant six
        // processes, six 15-second timeouts and a regex over its prose.
        // InstallState 1 is Enabled; a feature this SKU does not carry is
        // simply absent, which reads as Disabled the same way it did before.
        try
        {
            using var session = CimSession.Create(null);
            var enabled = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT Name FROM Win32_OptionalFeature WHERE InstallState = 1"))
            {
                var name = inst.CimInstanceProperties["Name"]?.Value?.ToString();
                if (!string.IsNullOrEmpty(name)) enabled.Add(name);
            }

            foreach (var (feature, info) in featureMap)
            {
                bool active = enabled.Contains(feature);
                rows.Add(new HealthRow(
                    info.Label,
                    active ? "Enabled" : "Disabled",
                    active ? (info.IsCritical ? CheckStatus.Bad : CheckStatus.Warning) : CheckStatus.Good));
            }
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "Win32_OptionalFeature query failed");
            rows.Add(new HealthRow("Optional features", "Query failed", CheckStatus.Unknown));
        }

        // Settings > Optional features lists these, and they stay installed
        // whether or not anything uses them. Being there is the finding.
        var capabilityMap = new Dictionary<string, (string Label, bool IsCritical)>(StringComparer.OrdinalIgnoreCase)
        {
            ["VBSCRIPT"] = ("VBScript", true),
            ["Browser.InternetExplorer"] = ("Internet Explorer mode", false),
            ["Media.WindowsMediaPlayer"] = ("Windows Media Player (app)", false),
            ["Microsoft.Windows.Notepad.System"] = ("Notepad (system)", false),
            ["Microsoft.Windows.PowerShell.ISE"] = ("PowerShell ISE", false),
        };

        var capabilities = GatherInstalledCapabilities();
        if (capabilities == null)
        {
            rows.Add(new HealthRow("Optional components", "Query failed", CheckStatus.Unknown));
        }
        else
        {
            // A capability name carries its version -- "VBSCRIPT~~~~",
            // "Media.WindowsMediaPlayer~~~~0.0.12.0" -- and the identity is
            // the part in front of it.
            var present = new HashSet<string>(
                capabilities.Select(n => n.Split('~')[0]), StringComparer.OrdinalIgnoreCase);

            foreach (var (capability, info) in capabilityMap)
            {
                bool active = present.Contains(capability);
                rows.Add(new HealthRow(
                    info.Label,
                    active ? "Installed" : "Not installed",
                    active ? (info.IsCritical ? CheckStatus.Bad : CheckStatus.Warning) : CheckStatus.Good));
            }
        }

        return rows;
    }

    /// <summary>
    /// The Features on Demand installed on this machine, or null when the
    /// query would not answer -- which is not the same as none being there.
    /// </summary>
    /// <remarks>
    /// The native route is DismApi.dll, and pcHealth took it first. A wrong
    /// P/Invoke signature there is an access violation, which no catch block
    /// can hold, and it took the whole app down on a live machine. This asks
    /// the same servicing stack through the DISM PowerShell module instead:
    /// a child process that misbehaves costs a row, not the app.
    ///
    /// The command prints one capability name per line, so there is no prose
    /// and no localised text to read around. It is passed base64 encoded
    /// because that is the one form a command line cannot mangle.
    /// </remarks>
    private static HashSet<string>? GatherInstalledCapabilities()
    {
        const string script =
            "Get-WindowsCapability -Online | "
            + "Where-Object { $_.State -eq 'Installed' } | "
            + "ForEach-Object { $_.Name }";

        var host = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System),
            "WindowsPowerShell", "v1.0", "powershell.exe");
        if (!File.Exists(host))
        {
            Log.Debug("No Windows PowerShell at {Host}", host);
            return null;
        }

        var encoded = Convert.ToBase64String(Encoding.Unicode.GetBytes(script));
        var output = RunCapture(host, $"-NoProfile -NonInteractive -EncodedCommand {encoded}");
        if (output == null) return null;

        var installed = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var line in output.Split('\n'))
        {
            // Every capability name carries its version behind a tilde, so a
            // line without one is not one of them.
            var name = line.Trim();
            if (name.Contains('~')) installed.Add(name);
        }

        // Every Windows install has capabilities, so an empty answer means the
        // command did not run rather than that the machine is clean.
        return installed.Count > 0 ? installed : null;
    }

    // --- CPU helpers ---

    /// <summary>
    /// Win32_Processor reports "13th Gen Intel(R) Core(TM) i7-1360P", not the
    /// marketing name. Dropping the trademark marks is what lets the patterns
    /// below read like the name a person would write.
    /// </summary>
    private static string StripTrademarks(string name)
    {
        var s = Regex.Replace(name, @"\((?:R|TM)\)", " ", RegexOptions.IgnoreCase);
        return Regex.Replace(s, @"\s+", " ").Trim();
    }

    private static (int year, string label) TryGetCpuReleaseYear(string rawName)
    {
        var name = StripTrademarks(rawName);

        if (Regex.IsMatch(name, @"Ryzen AI"))
            return (2024, "AMD Ryzen AI");

        var m = Regex.Match(name, @"Core i\d+-(\d{4,5})");
        if (m.Success)
        {
            var model = m.Groups[1].Value;

            // Intel puts the generation in front of its own name from the 8th
            // generation on, and that beats guessing from the model number.
            var gm = Regex.Match(name, @"\b(\d{1,2})th Gen\b");

            // A four-digit model starting with 1 is a mobile part from the 10th
            // generation on (i7-1065G7, i7-1360P), never a first-generation one:
            // those were three digits, so they never reach this branch.
            int gen = gm.Success ? int.Parse(gm.Groups[1].Value)
                : model.Length == 5 || model[0] == '1' ? int.Parse(model[..2])
                : model[0] - '0';

            int year = gen switch
            {
                1 => 2010,
                2 => 2011,
                3 => 2012,
                4 => 2013,
                5 => 2015,
                6 => 2015,
                7 => 2017,
                8 => 2018,
                9 => 2019,
                10 => 2020,
                11 => 2021,
                12 => 2022,
                13 => 2023,
                14 => 2023,
                15 => 2024,
                _ => -1
            };
            if (year > 0) return (year, $"Intel {gen}{Ordinal(gen)} gen");
        }

        var mu = Regex.Match(name, @"Core Ultra \d+ (\d{3,4})");
        if (mu.Success)
        {
            int series = mu.Groups[1].Value[0] - '0';
            int year = series switch { 1 => 2023, 2 => 2024, _ => 2024 };
            return (year, $"Intel Core Ultra Series {series}");
        }

        var mr = Regex.Match(name, @"Ryzen \d+ (\d)\d{3}");
        if (mr.Success)
        {
            int series = mr.Groups[1].Value[0] - '0';
            int year = series switch
            {
                1 => 2017,
                2 => 2018,
                3 => 2019,
                4 => 2020,
                5 => 2021,
                6 => 2022,
                7 => 2023,
                8 => 2024,
                9 => 2024,
                _ => -1
            };
            if (year > 0) return (year, $"AMD Ryzen {series}000 series");
        }

        return (-1, "");
    }

    // --- GPU helpers ---

    private static int? TryGetGpuReleaseYearRegex(string name)
    {
        var m = Regex.Match(name, @"RTX\s*(\d{2})\d{2}", RegexOptions.IgnoreCase);
        if (m.Success && int.TryParse(m.Groups[1].Value, out int rtxSeries))
            return rtxSeries switch { 50 => 2025, 40 => 2022, 30 => 2020, 20 => 2018, _ => null };

        if (Regex.IsMatch(name, @"GTX\s*16\d{2}", RegexOptions.IgnoreCase)) return 2019;
        if (Regex.IsMatch(name, @"GTX\s*10\d{2}", RegexOptions.IgnoreCase)) return 2016;
        if (Regex.IsMatch(name, @"GTX\s*9\d{2}\b", RegexOptions.IgnoreCase)) return 2014;

        if (Regex.IsMatch(name, @"RX\s*9\d{3}\b", RegexOptions.IgnoreCase)) return 2025;
        if (Regex.IsMatch(name, @"RX\s*7\d{3}\b", RegexOptions.IgnoreCase)) return 2022;
        if (Regex.IsMatch(name, @"RX\s*6\d{3}\b", RegexOptions.IgnoreCase)) return 2020;
        if (Regex.IsMatch(name, @"RX\s*5\d{3}\b", RegexOptions.IgnoreCase)) return 2019;
        if (Regex.IsMatch(name, @"RX\s*[45]\d{2}\b", RegexOptions.IgnoreCase)) return 2017;

        if (Regex.IsMatch(name, @"Arc\s*B\d{3}", RegexOptions.IgnoreCase)) return 2024;
        if (Regex.IsMatch(name, @"Arc\s*A\d{3}", RegexOptions.IgnoreCase)) return 2022;

        return null;
    }

    // --- RAM helpers ---

    private static string ResolveRamManufacturer(string mfr, string pn)
    {
        if (!string.IsNullOrEmpty(mfr) && mfr != "Unknown" && mfr.Length > 2) return mfr;
        return pn switch
        {
            var p when p.StartsWith("CM", StringComparison.OrdinalIgnoreCase) => "Corsair",
            var p when p.StartsWith("CT", StringComparison.OrdinalIgnoreCase)
                    || p.StartsWith("BL", StringComparison.OrdinalIgnoreCase) => "Crucial",
            var p when p.StartsWith("KVR", StringComparison.OrdinalIgnoreCase) => "Kingston",
            var p when p.StartsWith("HX", StringComparison.OrdinalIgnoreCase) => "HyperX / Kingston",
            var p when p.StartsWith("F4-", StringComparison.OrdinalIgnoreCase)
                    || p.StartsWith("F5-", StringComparison.OrdinalIgnoreCase) => "G.Skill",
            var p when p.StartsWith("TED", StringComparison.OrdinalIgnoreCase)
                    || p.StartsWith("TEAMGROUP", StringComparison.OrdinalIgnoreCase) => "TeamGroup",
            var p when p.StartsWith("MTA", StringComparison.OrdinalIgnoreCase)
                    || p.StartsWith("MT", StringComparison.OrdinalIgnoreCase) => "Micron",
            var p when p.StartsWith("M378", StringComparison.OrdinalIgnoreCase)
                    || p.StartsWith("M471", StringComparison.OrdinalIgnoreCase) => "Samsung",
            var p when p.StartsWith("AD4", StringComparison.OrdinalIgnoreCase)
                    || p.StartsWith("AX4", StringComparison.OrdinalIgnoreCase) => "ADATA",
            _ => mfr.Length > 0 ? mfr : "Unknown"
        };
    }

    // --- General helpers ---

    private static long? TryGetLongMs(Dictionary<string, string> map, params string[] keys)
    {
        foreach (var key in keys)
            if (map.TryGetValue(key, out var v) && long.TryParse(v, out long ms))
                return ms;
        return null;
    }

    private static string Ordinal(int n) => (n % 100) switch
    {
        11 or 12 or 13 => "th",
        _ => (n % 10) switch { 1 => "st", 2 => "nd", 3 => "rd", _ => "th" }
    };
}
