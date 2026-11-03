using System.Runtime.InteropServices;

namespace pcHealth.Helpers;

/// <summary>
/// Firmware type of the running system. The PEFirmwareType registry value
/// only exists inside Windows PE, so on an installed system the documented
/// GetFirmwareType API is the reliable source.
/// </summary>
internal static class Firmware
{
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetFirmwareType(out uint firmwareType);

    /// <summary>Returns "UEFI", "BIOS" or "Unknown".</summary>
    internal static string GetTypeName()
    {
        if (!GetFirmwareType(out var type)) return "Unknown";
        return type switch
        {
            1 => "BIOS",
            2 => "UEFI",
            _ => "Unknown",
        };
    }

    internal static bool IsUefi() => GetTypeName() == "UEFI";
}
