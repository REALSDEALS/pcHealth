using Microsoft.UI.Xaml.Media;
using pcHealth.ViewModels;
using Windows.Devices.Power;

namespace pcHealth.Pages;

public sealed partial class HealthPage : Page
{
    public HealthViewModel ViewModel { get; } = App.Services.GetRequiredService<HealthViewModel>();

    // Live battery update state
    private TextBlock? _battChargeLevelText;
    private TextBlock? _battPowerDrawText;
    private ProgressBar? _battProgressBar;
    private int? _battFullCapacityMwh;
    private DispatcherTimer? _battTimer;

    public HealthPage()
    {
        InitializeComponent();
        Loaded += OnLoaded;
        Unloaded += (_, _) => { _battTimer?.Stop(); _battTimer = null; };
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        try
        {
            await ViewModel.LoadCommand.ExecuteAsync(null);
            if (!IsLoaded) return;
            if (ViewModel.Data is not null)
                PopulateUi(ViewModel.Data);
            else if (!string.IsNullOrEmpty(ViewModel.ErrorMessage))
            {
                LoadingPanel.Visibility = Visibility.Collapsed;
                ErrorBar.Message = ViewModel.ErrorMessage;
                ErrorBar.IsOpen = true;
            }
        }
        catch (Exception ex)
        {
            LoadingPanel.Visibility = Visibility.Collapsed;
            ErrorBar.Message = ex.Message;
            ErrorBar.IsOpen = true;
        }
    }

    // UI population

    private static CheckStatus WorstStatus(IEnumerable<CheckStatus> statuses) =>
        HealthStatusHelper.WorstStatus(statuses);

    private void SetStatusDot(Microsoft.UI.Xaml.Shapes.Ellipse dot, CheckStatus status)
    {
        var key = status switch
        {
            CheckStatus.Good => "SystemFillColorSuccessBrush",
            CheckStatus.Warning => "SystemFillColorCautionBrush",
            CheckStatus.Bad => "SystemFillColorCriticalBrush",
            _ => "TextFillColorSecondaryBrush",
        };
        if (Application.Current.Resources.TryGetValue(key, out var b))
            dot.Fill = (Brush)b;
    }

    private void PopulateUi(HealthData data)
    {
        LoadingPanel.Visibility = Visibility.Collapsed;

        SetStatusDot(CpuStatusDot, PopulateCard(CpuRows, data.Cpu, CpuExpander));
        SetStatusDot(GpuStatusDot, PopulateGpuCard(GpuRows, data.Gpu, GpuExpander));
        SetStatusDot(RamStatusDot, PopulateRamCard(RamRows, data.Ram, RamExpander));
        SetStatusDot(SmartStatusDot, PopulateDiskHealthCard(SmartRows, data.Smart, data.SmartUsedSmartctl, SmartExpander));
        SetStatusDot(DiskStatusDot, PopulateDriveCard(DiskSpaceRows, data.DiskSpace, DiskExpander));
        SetStatusDot(WinVerStatusDot, PopulateCard(WinVerRows, data.WinVer, WinVerExpander));
        SetStatusDot(BootStatusDot, PopulateCard(BootRows, data.Boot, BootExpander));

        if (data.Battery != null)
            SetStatusDot(BatteryStatusDot, PopulateBatteryCard(BatteryRows, data.Battery, BatteryExpander));

        SetStatusDot(SecurityStatusDot, PopulateSecurityCard(SecurityRows, data.Security, SecurityExpander));
        SetStatusDot(LegacyStatusDot, PopulateLegacyFeaturesCard(LegacyRows, data.LegacyFeatures, LegacyExpander));
    }

    private CheckStatus PopulateCard(StackPanel panel, List<HealthRow> rows, Expander expander)
    {
        foreach (var row in rows)
            AddStatusRow(panel, row.Label, row.Value, row.Status);
        expander.Visibility = Visibility.Visible;
        return WorstStatus(rows.Select(r => r.Status));
    }

    private CheckStatus PopulateGpuCard(StackPanel panel, List<GpuInfo> gpus, Expander expander)
    {
        bool first = true;
        var statuses = new List<CheckStatus>();
        foreach (var g in gpus)
        {
            if (!first) AddSeparator(panel);
            first = false;

            panel.Children.Add(new TextBlock
            {
                Text = g.Name,
                Style = (Style)Application.Current.Resources["BodyStrongTextBlockStyle"],
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 4),
            });

            if (g.ReleaseYear.HasValue)
            {
                int age = DateTime.Today.Year - g.ReleaseYear.Value;
                var s = age >= 10 ? CheckStatus.Bad : age >= 5 ? CheckStatus.Warning : CheckStatus.Good;
                statuses.Add(s);
                if (g.SeriesName != null)
                    AddStatusRow(panel, "Generation", g.SeriesName, CheckStatus.Info);
                AddStatusRow(panel, "Release year", g.ReleaseYear.Value.ToString(), s);
            }
            else
            {
                AddStatusRow(panel, "Release year", "Unknown", CheckStatus.Unknown);
                statuses.Add(CheckStatus.Unknown);
            }

            if (g.DriverAgeMonths.HasValue)
            {
                int months = g.DriverAgeMonths.Value;
                var s = months > 18 ? CheckStatus.Warning : CheckStatus.Good;
                statuses.Add(s);
                var txt = months < 12
                    ? $"{months} month{(months == 1 ? "" : "s")}"
                    : $"~{months / 12} year{(months / 12 > 1 ? "s" : "")}";
                AddStatusRow(panel, "Driver age", txt, s);
            }
            else
            {
                AddStatusRow(panel, "Driver age", "Unknown", CheckStatus.Unknown);
                statuses.Add(CheckStatus.Unknown);
            }
        }
        expander.Visibility = Visibility.Visible;
        return WorstStatus(statuses);
    }

    private CheckStatus PopulateRamCard(StackPanel panel, List<RamModule> modules, Expander expander)
    {
        var statuses = new List<CheckStatus>();
        if (modules.Count == 0)
        {
            AddStatusRow(panel, "RAM", "No modules found", CheckStatus.Unknown);
            expander.Visibility = Visibility.Visible;
            return CheckStatus.Unknown;
        }

        double totalGb = modules.Sum(m => m.CapacityGb);
        int minSpeed = modules.Where(m => m.SpeedMts > 0).Select(m => m.SpeedMts).DefaultIfEmpty(0).Min();

        var totalStatus = totalGb >= 16 ? CheckStatus.Good
                        : totalGb >= 12 ? CheckStatus.Warning
                        : CheckStatus.Bad;
        statuses.Add(totalStatus);
        AddStatusRow(panel, "Total installed", totalGb > 0 ? $"{totalGb:F0} GB" : "Unknown total", totalStatus);
        if (totalStatus == CheckStatus.Bad)
            AddStatusRow(panel, "RAM note", "Under 12 GB - below 2026 minimum (>=16 GB recommended)", CheckStatus.Bad);
        else if (totalStatus == CheckStatus.Warning)
            AddStatusRow(panel, "RAM note", "12-15 GB - at minimum; 16 GB+ recommended for 2026", CheckStatus.Warning);

        if (minSpeed > 0)
        {
            var ddrType = modules.FirstOrDefault(m => m.MemoryType > 0)?.MemoryType switch
            {
                24 => "DDR3",
                26 => "DDR4",
                34 => "DDR5",
                _ => null
            };
            var speedStatus = ddrType switch
            {
                "DDR3" => CheckStatus.Bad,
                "DDR4" => CheckStatus.Warning,
                "DDR5" => CheckStatus.Good,
                _ => minSpeed < 5200 ? CheckStatus.Warning : CheckStatus.Good,
            };
            statuses.Add(speedStatus);
            var speedLabel = ddrType != null ? $"{minSpeed} MT/s ({ddrType})" : $"{minSpeed} MT/s";
            AddStatusRow(panel, "Speed", speedLabel, speedStatus);
            if (speedStatus == CheckStatus.Bad)
                AddStatusRow(panel, "Speed note", "DDR3 - very old, significantly slower than DDR4/DDR5", CheckStatus.Bad);
            else if (speedStatus == CheckStatus.Warning)
                AddStatusRow(panel, "Speed note",
                    ddrType == "DDR4"
                        ? "DDR4 - functional but not future-proof; DDR5 recommended"
                        : "Below 5200 MT/s - slower than modern DDR5",
                    CheckStatus.Warning);
        }

        AddSeparator(panel);

        bool first = true;
        foreach (var mod in modules)
        {
            if (!first) AddSeparator(panel);
            first = false;

            var capStr = mod.CapacityGb > 0 ? $"{mod.CapacityGb:F0} GB" : "?";
            var speedStr = mod.SpeedMts > 0 ? $"{mod.SpeedMts} MT/s" : "Unknown speed";
            panel.Children.Add(new TextBlock
            {
                Text = $"{mod.Slot}   {capStr}  {speedStr}",
                Style = (Style)Application.Current.Resources["BodyStrongTextBlockStyle"],
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 4),
            });

            if (!string.IsNullOrEmpty(mod.PartNumber))
                AddStatusRow(panel, "Part number", mod.PartNumber, CheckStatus.Info);
            if (mod.Manufacturer != "Unknown" && !string.IsNullOrEmpty(mod.Manufacturer))
                AddStatusRow(panel, "Manufacturer", mod.Manufacturer, CheckStatus.Info);
        }

        expander.Visibility = Visibility.Visible;
        return WorstStatus(statuses);
    }

    private CheckStatus PopulateDiskHealthCard(StackPanel panel, List<DiskHealthInfo> disks,
        bool usedSmartctl, Expander expander)
    {
        var statuses = new List<CheckStatus>();
        if (!usedSmartctl)
            AddStatusRow(panel, "Data source", "Install smartmontools for life % data", CheckStatus.Info);

        bool first = true;
        foreach (var d in disks)
        {
            if (!first) AddSeparator(panel);
            first = false;

            panel.Children.Add(new TextBlock
            {
                Text = $"{d.Name}  ({d.MediaType})",
                Style = (Style)Application.Current.Resources["BodyStrongTextBlockStyle"],
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 4),
            });

            statuses.Add(d.HealthStatus);
            AddStatusRow(panel, "Health", d.HealthText, d.HealthStatus);

            if (d.SpeedFlag != null)
            {
                statuses.Add(CheckStatus.Warning);
                AddStatusRow(panel, "Interface note", d.SpeedFlag, CheckStatus.Warning);
            }

            if (d.Wear.HasValue)
            {
                byte used = d.Wear.Value;
                byte rem = (byte)(100 - Math.Min(used, (byte)100));
                var s = used > 80 ? CheckStatus.Bad : used > 50 ? CheckStatus.Warning : CheckStatus.Good;
                statuses.Add(s);
                AddStatusRow(panel, "Life remaining", $"{rem}%  ({used}% used)", s);
            }
            else
            {
                AddStatusRow(panel, "Life remaining", "Not reported by drive", CheckStatus.Unknown);
            }

            if (d.Temperature.HasValue && d.Temperature.Value > 0)
            {
                ushort t = d.Temperature.Value;
                var s = t > 60 ? CheckStatus.Bad : t > 45 ? CheckStatus.Warning : CheckStatus.Good;
                statuses.Add(s);
                AddStatusRow(panel, "Temperature", $"{t}°C", s);
            }
            if (d.PowerOnHours.HasValue && d.PowerOnHours.Value > 0)
            {
                ulong h = d.PowerOnHours.Value;
                AddStatusRow(panel, "Power-on hours", $"{h:N0}h", CheckStatus.Info);
            }
            if (d.TbwGb.HasValue)
                AddStatusRow(panel, "Total written", $"{d.TbwGb.Value:N0} GB", CheckStatus.Info);
        }
        expander.Visibility = Visibility.Visible;
        return WorstStatus(statuses);
    }

    private CheckStatus PopulateDriveCard(StackPanel panel, List<DriveRow> rows, Expander expander)
    {
        var statuses = new List<CheckStatus>();
        if (rows.Count == 0)
        {
            AddStatusRow(panel, "Status", "No fixed drives found", CheckStatus.Unknown);
            statuses.Add(CheckStatus.Unknown);
        }

        foreach (var r in rows)
        {
            double pct = r.TotalBytes > 0 ? (double)r.UsedBytes / r.TotalBytes * 100 : 0;
            double usedGb = r.UsedBytes / 1_073_741_824.0;
            double totalGb = r.TotalBytes / 1_073_741_824.0;
            double freeGb = (r.TotalBytes - r.UsedBytes) / 1_073_741_824.0;

            statuses.Add(r.Status);
            AddStatusRow(panel, r.Drive,
                $"{usedGb:F0} GB used  /  {totalGb:F0} GB total  ·  {freeGb:F0} GB free",
                r.Status);

            var barRow = new Grid { Margin = new Thickness(0, 3, 0, 8) };
            barRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            barRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var bar = new ProgressBar { Value = pct, Maximum = 100 };
            Grid.SetColumn(bar, 0);

            var pctLabel = new TextBlock
            {
                Text = $"{pct:F0}%",
                Style = (Style)Application.Current.Resources["CaptionTextBlockStyle"],
                Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
                Margin = new Thickness(10, 0, 0, 0),
                VerticalAlignment = VerticalAlignment.Center,
            };
            Grid.SetColumn(pctLabel, 1);

            barRow.Children.Add(bar);
            barRow.Children.Add(pctLabel);
            panel.Children.Add(barRow);
        }
        expander.Visibility = Visibility.Visible;
        return WorstStatus(statuses);
    }

    private CheckStatus PopulateBatteryCard(StackPanel panel, BatteryInfo bat, Expander expander)
    {
        var statuses = new List<CheckStatus>();

        if (bat.DesignCapacityMwh is > 0 && bat.FullChargeCapacityMwh.HasValue)
        {
            double health = (double)bat.FullChargeCapacityMwh.Value / bat.DesignCapacityMwh.Value * 100;
            var s = health >= 80 ? CheckStatus.Good : health >= 50 ? CheckStatus.Warning : CheckStatus.Bad;
            statuses.Add(s);
            double designWh = bat.DesignCapacityMwh.Value / 1000.0;
            double fullWh = bat.FullChargeCapacityMwh.Value / 1000.0;
            AddStatusRow(panel, "Battery health", $"{health:F0}%  ({fullWh:F1} Wh / {designWh:F1} Wh design)", s);

            var healthLabel = s switch
            {
                CheckStatus.Good => "Good",
                CheckStatus.Warning => "Aging - monitor regularly",
                _ => "Poor - consider replacing",
            };
            AddStatusRow(panel, "Health status", healthLabel, s);
        }

        if (bat.RemainingCapacityMwh.HasValue && bat.FullChargeCapacityMwh is > 0)
        {
            _battFullCapacityMwh = bat.FullChargeCapacityMwh.Value;
            double chargeOfMax = (double)bat.RemainingCapacityMwh.Value / bat.FullChargeCapacityMwh.Value * 100;
            double remWh = bat.RemainingCapacityMwh.Value / 1000.0;
            _battChargeLevelText = AddStatusRowRef(panel, "Charge level",
                $"{chargeOfMax:F0}%  ({remWh:F1} Wh remaining)", CheckStatus.Info);
            var pb = new ProgressBar { Value = chargeOfMax, Maximum = 100, Margin = new Thickness(0, 2, 0, 4) };
            panel.Children.Add(pb);
            _battProgressBar = pb;
        }

        if (bat.ChargeRateMw.HasValue)
        {
            int mw = bat.ChargeRateMw.Value;
            string powerText = mw < 0 ? $"Discharging  ({Math.Abs(mw) / 1000.0:F1} W)"
                             : mw > 0 ? $"Charging  ({mw / 1000.0:F1} W)"
                             : "Idle  (plugged in, not charging)";
            _battPowerDrawText = AddStatusRowRef(panel, "Power draw", powerText, CheckStatus.Info);
        }
        else
        {
            AddStatusRow(panel, "Status", bat.StatusText, CheckStatus.Info);
        }

        if (bat.EstimatedRuntimeMin is > 0)
        {
            int mins = bat.EstimatedRuntimeMin.Value;
            string runtimeText = mins >= 60 ? $"{mins / 60}h {mins % 60}min" : $"{mins} min";
            AddStatusRow(panel, "Estimated runtime", runtimeText, CheckStatus.Info);
        }

        if (bat.CycleCountQueried)
        {
            int cc = bat.CycleCount ?? 0;
            if (cc > 0 && cc < 9999)
            {
                var s = cc > 1000 ? CheckStatus.Bad : cc > 500 ? CheckStatus.Warning : CheckStatus.Good;
                statuses.Add(s);
                AddStatusRow(panel, "Cycle count", cc.ToString(), s);
            }
            else
            {
                AddStatusRow(panel, "Cycle count", "Not reported by driver", CheckStatus.Unknown);
            }
        }

        if (bat.BatteryAgeMonths is > 0)
        {
            int months = bat.BatteryAgeMonths.Value;
            string ageText = months >= 12
                ? $"~{months / 12} year{(months / 12 > 1 ? "s" : "")}  ({months} months)"
                : $"{months} month{(months == 1 ? "" : "s")}";
            var s = months > 48 ? CheckStatus.Warning : CheckStatus.Info;
            if (s == CheckStatus.Warning) statuses.Add(s);
            AddStatusRow(panel, "Battery age", ageText, s);
        }

        if (!string.IsNullOrEmpty(bat.Chemistry) && bat.Chemistry != "Unknown")
            AddStatusRow(panel, "Chemistry", bat.Chemistry, CheckStatus.Info);

        expander.Visibility = Visibility.Visible;

        _battTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(3) };
        _battTimer.Tick += OnBatteryTimerTick;
        _battTimer.Start();

        return WorstStatus(statuses.Count > 0 ? statuses : [CheckStatus.Info]);
    }

    private void OnBatteryTimerTick(object? sender, object e)
    {
        try
        {
            var report = Battery.AggregateBattery.GetReport();

            if (_battChargeLevelText != null && _battFullCapacityMwh is > 0
                && report.RemainingCapacityInMilliwattHours.HasValue)
            {
                double chargeOfMax = (double)report.RemainingCapacityInMilliwattHours.Value / _battFullCapacityMwh.Value * 100;
                double remWh = report.RemainingCapacityInMilliwattHours.Value / 1000.0;
                _battChargeLevelText.Text = $"{chargeOfMax:F0}%  ({remWh:F1} Wh remaining)";
                if (_battProgressBar != null)
                    _battProgressBar.Value = chargeOfMax;
            }

            if (_battPowerDrawText != null && report.ChargeRateInMilliwatts.HasValue)
            {
                int mw = report.ChargeRateInMilliwatts.Value;
                _battPowerDrawText.Text = mw < 0 ? $"Discharging  ({Math.Abs(mw) / 1000.0:F1} W)"
                                        : mw > 0 ? $"Charging  ({mw / 1000.0:F1} W)"
                                        : "Idle  (plugged in, not charging)";
            }
        }
        catch (Exception ex)
        {
            // Ticks every 3s, so log at Debug: a removed or sleeping battery
            // would otherwise fill the log with the same entry.
            NLog.LogManager.GetCurrentClassLogger().Debug(ex, "Live battery reading failed");
        }
    }

    private CheckStatus PopulateSecurityCard(StackPanel panel, SecurityInfo data, Expander expander)
    {
        var statuses = new List<CheckStatus>();

        void AddSection(string title, List<HealthRow> rows)
        {
            panel.Children.Add(new TextBlock
            {
                Text = title,
                Style = (Style)Application.Current.Resources["BodyStrongTextBlockStyle"],
                Margin = new Thickness(0, 0, 0, 4),
            });
            foreach (var r in rows)
            {
                AddStatusRow(panel, r.Label, r.Value, r.Status);
                if (r.Status != CheckStatus.Info) statuses.Add(r.Status);
            }
        }

        AddSection("Windows Defender", data.Defender);
        AddSeparator(panel);
        AddSection("BitLocker", data.BitLocker);
        AddSeparator(panel);
        AddSection("Secure Boot", data.SecureBoot);
        AddSeparator(panel);
        AddSection("TPM", data.Tpm);

        expander.Visibility = Visibility.Visible;
        return WorstStatus(statuses.Count > 0 ? statuses : [CheckStatus.Info]);
    }

    private CheckStatus PopulateLegacyFeaturesCard(StackPanel panel, List<HealthRow> rows, Expander expander)
    {
        if (rows.Count == 0)
        {
            AddStatusRow(panel, "Status", "No checks available", CheckStatus.Unknown);
            expander.Visibility = Visibility.Visible;
            return CheckStatus.Unknown;
        }
        foreach (var r in rows)
            AddStatusRow(panel, r.Label, r.Value, r.Status);
        expander.Visibility = Visibility.Visible;
        return WorstStatus(rows.Select(r => r.Status));
    }

    private void AddSeparator(StackPanel panel) =>
        panel.Children.Add(new Border
        {
            Height = 1,
            Margin = new Thickness(0, 8, 0, 8),
            Background = (Brush)Application.Current.Resources["CardStrokeColorDefaultBrush"],
        });

    private TextBlock AddStatusRowRef(StackPanel panel, string label, string value, CheckStatus status)
    {
        AddStatusRow(panel, label, value, status);
        var grid = (Grid)panel.Children[panel.Children.Count - 1];
        return (TextBlock)grid.Children[2];
    }

    private void AddStatusRow(StackPanel panel, string label, string value, CheckStatus status)
    {
        var grid = new Grid { ColumnSpacing = 10, Margin = new Thickness(0, 1, 0, 1) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(160) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var lbl = new TextBlock
        {
            Text = label,
            Style = (Style)Application.Current.Resources["CaptionTextBlockStyle"],
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
            VerticalAlignment = VerticalAlignment.Center,
        };

        var (glyph, brushKey) = status switch
        {
            CheckStatus.Good => ("", "SystemFillColorSuccessBrush"),
            CheckStatus.Bad => ("", "SystemFillColorCriticalBrush"),
            CheckStatus.Warning => ("", "SystemFillColorCautionBrush"),
            CheckStatus.Info => ("", "TextFillColorSecondaryBrush"),
            _ => ("", "TextFillColorSecondaryBrush"),
        };

        var icon = new FontIcon
        {
            Glyph = glyph,
            FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center,
            Foreground = Application.Current.Resources.TryGetValue(brushKey, out var b)
                                    ? (Brush)b
                                    : (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
        };

        var val = new TextBlock
        {
            Text = value,
            IsTextSelectionEnabled = true,
            TextWrapping = TextWrapping.Wrap,
            VerticalAlignment = VerticalAlignment.Center,
        };

        Grid.SetColumn(icon, 1);
        Grid.SetColumn(val, 2);
        grid.Children.Add(lbl);
        grid.Children.Add(icon);
        grid.Children.Add(val);
        panel.Children.Add(grid);
    }
}
