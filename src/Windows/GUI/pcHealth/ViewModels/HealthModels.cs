namespace pcHealth.ViewModels;

public enum CheckStatus { Good, Warning, Bad, Unknown, Info }

public record HealthRow(string Label, string Value, CheckStatus Status);
public record DriveRow(string Drive, long UsedBytes, long TotalBytes, CheckStatus Status);

public record GpuInfo(
    string Name,
    int? DriverAgeMonths,
    int? ReleaseYear,
    string? SeriesName);

public record RamModule(
    string Slot,
    double CapacityGb,
    int SpeedMts,
    int MemoryType,
    string PartNumber,
    string Manufacturer);

public record DiskHealthInfo(
    string Name,
    string MediaType,
    CheckStatus HealthStatus,
    string HealthText,
    byte? Wear,
    ushort? Temperature,
    ulong? PowerOnHours,
    string? SpeedFlag,
    ulong? TbwGb
);

public record BatteryInfo(
    string? Name,
    string? Chemistry,
    int? DesignCapacityMwh,
    int? FullChargeCapacityMwh,
    int? RemainingCapacityMwh,
    int? ChargeRateMw,
    string StatusText,
    int? EstimatedRuntimeMin,
    int? CycleCount,
    bool CycleCountQueried,
    int? BatteryAgeMonths
);

public record SecurityInfo(
    List<HealthRow> Defender,
    List<HealthRow> BitLocker,
    List<HealthRow> SecureBoot,
    List<HealthRow> Tpm
);

public record HealthData(
    List<HealthRow> Cpu,
    List<GpuInfo> Gpu,
    List<RamModule> Ram,
    List<DiskHealthInfo> Smart,
    bool SmartUsedSmartctl,
    List<DriveRow> DiskSpace,
    List<HealthRow> WinVer,
    List<HealthRow> Boot,
    BatteryInfo? Battery,
    SecurityInfo Security,
    List<HealthRow> LegacyFeatures
);

public static class HealthStatusHelper
{
    public static CheckStatus WorstStatus(IEnumerable<CheckStatus> statuses)
    {
        var worst = CheckStatus.Info;
        foreach (var s in statuses)
        {
            if (s == CheckStatus.Bad) return CheckStatus.Bad;
            if (s == CheckStatus.Warning && worst != CheckStatus.Bad) worst = CheckStatus.Warning;
            if (s == CheckStatus.Good && worst is CheckStatus.Info or CheckStatus.Unknown) worst = CheckStatus.Good;
            if (s == CheckStatus.Unknown && worst == CheckStatus.Info) worst = CheckStatus.Unknown;
        }
        return worst;
    }
}
