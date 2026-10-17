using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using System.Diagnostics;

namespace pcHealth.ViewModels;

public partial class OpenBatteryReportViewModel : ObservableObject
{
    private readonly string _reportPath =
        Path.Combine(Path.GetTempPath(), "pcHealth-battery-report.html");

    [ObservableProperty] public partial string ReportInfo { get; set; } = "";
    [ObservableProperty] public partial bool ReportExists { get; set; }

    public string ReportPath => _reportPath;

    [RelayCommand]
    public void Load()
    {
        if (File.Exists(_reportPath))
        {
            var info = new FileInfo(_reportPath);
            ReportInfo = $"Report location: {_reportPath}\nLast generated: {info.LastWriteTime:yyyy-MM-dd HH:mm:ss}";
            ReportExists = true;
        }
        else
        {
            ReportInfo = $"Report location: {_reportPath}";
            ReportExists = false;
        }
    }

    [RelayCommand(CanExecute = nameof(ReportExists))]
    public void Open()
    {
        if (!File.Exists(_reportPath)) { ReportExists = false; return; }
        Process.Start(new ProcessStartInfo(_reportPath) { UseShellExecute = true });
    }
}
