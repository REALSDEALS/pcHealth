using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Management.Infrastructure;
using NLog;
using System.Diagnostics;

namespace pcHealth.ViewModels;

public partial class BatteryReportViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    [ObservableProperty] public partial bool IsLoading { get; set; } = true;
    // The button binds to the command before LoadAsync has found the battery,
    // so CanGenerate must be re-evaluated when these change.
    [ObservableProperty, NotifyCanExecuteChangedFor(nameof(GenerateReportCommand))]
    public partial bool HasBattery { get; set; }
    [ObservableProperty, NotifyCanExecuteChangedFor(nameof(GenerateReportCommand))]
    public partial bool IsGenerating { get; set; }
    [ObservableProperty] public partial string GenerateStatus { get; set; } = "";
    [ObservableProperty] public partial string ErrorMessage { get; set; } = "";
    [ObservableProperty] public partial IReadOnlyList<(string Label, string Value)> Rows { get; set; } = [];

    [RelayCommand]
    public async Task LoadAsync()
    {
        try
        {
            var (found, rows) = await Task.Run(GatherBatteryData);
            HasBattery = found;
            Rows = rows;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Battery data gather failed");
            ErrorMessage = ex.Message;
        }
        finally
        {
            IsLoading = false;
        }
    }

    [RelayCommand(CanExecute = nameof(CanGenerate))]
    public async Task GenerateReportAsync()
    {
        IsGenerating = true;
        GenerateStatus = "Generating report…";
        try
        {
            var reportPath = Path.Combine(Path.GetTempPath(), "pcHealth-battery-report.html");
            await Task.Run(() =>
            {
                // A report left over from an earlier run would otherwise be
                // opened as if it were new when powercfg fails.
                File.Delete(reportPath);
                // powercfg has no /quiet switch for /batteryreport; passing one makes it fail.
                var psi = new ProcessStartInfo { FileName = "powercfg.exe", UseShellExecute = false, CreateNoWindow = true };
                psi.ArgumentList.Add("/batteryreport");
                psi.ArgumentList.Add("/output");
                psi.ArgumentList.Add(reportPath);
                using var proc = Process.Start(psi);
                proc?.WaitForExit(30_000);
            });

            if (File.Exists(reportPath))
            {
                GenerateStatus = "Report generated.";
                Process.Start(new ProcessStartInfo(reportPath) { UseShellExecute = true });
            }
            else
            {
                GenerateStatus = "powercfg did not create a battery report.";
            }
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Battery report generation failed");
            GenerateStatus = $"Failed: {ex.Message}";
        }
        finally
        {
            IsGenerating = false;
        }
    }

    private bool CanGenerate() => !IsGenerating && HasBattery;

    private static (bool Found, IReadOnlyList<(string, string)> Rows) GatherBatteryData()
    {
        using var session = CimSession.Create(null);
        var rows = new List<(string, string)>();

        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT Name, BatteryStatus, EstimatedChargeRemaining, EstimatedRunTime, Chemistry FROM Win32_Battery"))
        {
            rows.Add(("Name", inst.CimInstanceProperties["Name"]?.Value?.ToString() ?? "Unknown"));
            if (inst.CimInstanceProperties["BatteryStatus"]?.Value is ushort s)
                rows.Add(("Status", DecodeBatteryStatus(s)));
            if (inst.CimInstanceProperties["EstimatedChargeRemaining"]?.Value is ushort charge)
                rows.Add(("Charge", $"{charge}%"));
            if (inst.CimInstanceProperties["EstimatedRunTime"]?.Value is uint runtime && runtime < 71582)
                rows.Add(("Estimated Run Time", $"{runtime} min"));
            if (inst.CimInstanceProperties["Chemistry"]?.Value is ushort chem)
                rows.Add(("Chemistry", DecodeChemistry(chem)));
            return (true, rows);
        }
        return (false, rows);
    }

    private static string DecodeBatteryStatus(ushort code) => code switch
    {
        1 => "Discharging",
        2 => "On AC power",
        3 => "Fully charged",
        4 => "Low",
        5 => "Critical",
        6 => "Charging",
        7 => "Charging (High)",
        8 => "Charging (Low)",
        9 => "Charging (Critical)",
        11 => "Partially charged",
        _ => $"Unknown ({code})",
    };

    private static string DecodeChemistry(ushort code) => code switch
    {
        3 => "Lead Acid",
        4 => "Nickel Cadmium",
        5 => "Nickel Metal Hydride",
        6 => "Lithium-ion",
        7 => "Zinc Air",
        8 => "Lithium Polymer",
        _ => "Unknown",
    };
}
