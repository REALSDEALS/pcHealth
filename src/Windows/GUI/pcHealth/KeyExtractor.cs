using System.Diagnostics;
using System.Text.RegularExpressions;
using Microsoft.Management.Infrastructure;
using Microsoft.Win32;

namespace pcHealth;

/// <summary>Holds the result of a full key extraction run.</summary>
public sealed record LicenseResult(
    string OsCaption,
    string? Oa3Key,
    string? RegKey,
    string? BestKey,
    string BestSource,
    bool IsGeneric,
    string? GenericEdition
);

/// <summary>
/// Extracts the Windows product key using two independent methods:
///   1. OA3  - key stored in UEFI/BIOS firmware (most OEM machines)
///   2. DPID - key encoded in the registry DigitalProductId blob (all machines)
/// Both methods are read-only; nothing is written or modified.
/// </summary>
public static class KeyExtractor
{
    // KMS client setup keys shipped with Windows. They look like valid keys but
    // cannot activate a personal copy of Windows.
    private static readonly Dictionary<string, string> GenericKeys = new()
    {
        ["VK7JG-NPHTM-C97JM-9MPGT-3V66T"] = "Windows 11 Pro",
        ["YTMG3-N6DKC-DKB77-7M9GH-8HVX7"] = "Windows 11 Pro N",
        ["YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY"] = "Windows 11 Home",
        ["TX9XD-98N7V-6WMQ6-BX7FG-H8Q99"] = "Windows 11 Home N",
        ["NPPR9-FWDCX-D2C8J-H872K-2YT43"] = "Windows 11 Enterprise",
        ["NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J"] = "Windows 11 Pro for Workstations",
        ["W269N-WFGWX-YVC9B-4J6C9-T83GX"] = "Windows 10/11 Pro",
    };

    /// <summary>Runs both extraction methods and returns a combined result.</summary>
    public static LicenseResult Extract()
    {
        var osCaption = GetOsCaption();
        var oa3Key = GetKeyFromOA3();
        var regKey = GetKeyFromDigitalProductId();

        // Prefer the registry key (currently active) over the OA3 key (original OEM).
        string? bestKey = regKey ?? oa3Key;
        string bestSource = regKey != null ? "Registry (DigitalProductId)"
                               : oa3Key != null ? "UEFI/BIOS (OA3)"
                               : "None";
        bool isGeneric = bestKey != null && GenericKeys.ContainsKey(bestKey);
        string? genericEdition = isGeneric && bestKey != null
                               ? GenericKeys[bestKey]
                               : null;

        return new LicenseResult(osCaption, oa3Key, regKey, bestKey,
                                 bestSource, isGeneric, genericEdition);
    }

    private static string GetOsCaption()
    {
        try
        {
            using var session = CimSession.Create(null);
            foreach (var instance in session.QueryInstances(
                "root/cimv2", "WQL",
                "SELECT Caption, BuildNumber FROM Win32_OperatingSystem"))
            {
                var caption = instance.CimInstanceProperties["Caption"]?.Value?.ToString()?.Trim();
                var build = instance.CimInstanceProperties["BuildNumber"]?.Value?.ToString();
                if (caption != null)
                    return $"{caption} (Build {build})";
            }
        }
        catch (CimException ex)
        {
            Debug.WriteLine($"[KeyExtractor] CIM query failed for OS caption: {ex.Message}");
        }
        catch (UnauthorizedAccessException ex)
        {
            Debug.WriteLine($"[KeyExtractor] Access denied querying OS caption: {ex.Message}");
        }
        return "Windows (version unknown)";
    }

    private static string? GetKeyFromOA3()
    {
        try
        {
            using var session = CimSession.Create(null);
            foreach (var instance in session.QueryInstances(
                "root/cimv2", "WQL",
                "SELECT OA3xOriginalProductKey FROM SoftwareLicensingService"))
            {
                var key = instance.CimInstanceProperties["OA3xOriginalProductKey"]?.Value?.ToString();
                if (!string.IsNullOrWhiteSpace(key) && IsValidFormat(key))
                    return key;
            }
        }
        catch (CimException ex)
        {
            Debug.WriteLine($"[KeyExtractor] CIM query failed for OA3 key: {ex.Message}");
        }
        catch (UnauthorizedAccessException ex)
        {
            Debug.WriteLine($"[KeyExtractor] Access denied querying OA3 key: {ex.Message}");
        }
        return null;
    }

    private static string? GetKeyFromDigitalProductId()
    {
        try
        {
            using var regKey = Registry.LocalMachine.OpenSubKey(
                @"SOFTWARE\Microsoft\Windows NT\CurrentVersion");
            if (regKey?.GetValue("DigitalProductId") is not byte[] dpid)
                return null;

            // The encoded key occupies bytes 52-66 (15 bytes) of the blob.
            byte[] keyBytes = dpid[52..67];

            // Windows 8+ keys embed an 'N' character. Bit 3 of byte 14 is a flag
            // indicating where to reinsert it after decoding. Clear the flag bit
            // before decoding so it does not corrupt the base-24 result.
            const string Chars = "BCDFGHJKMPQRTVWXY2346789";
            int isWin8Plus = (keyBytes[14] >> 3) & 1;
            keyBytes[14] &= 0xF7; // Clear bit 3 - the N-insertion flag is not part of the encoded key.

            // Base-24 decode: treat the 15-byte array as a base-256 number and
            // convert it digit-by-digit into a 25-character base-24 string.
            var decoded = new char[25];
            for (int i = 24; i >= 0; i--)
            {
                int cur = 0;
                for (int j = 14; j >= 0; j--)
                {
                    cur = (cur << 8) | keyBytes[j];
                    keyBytes[j] = (byte)(cur / 24);
                    cur %= 24;
                }
                decoded[i] = Chars[cur];
            }

            string result = new(decoded);

            // Re-insert the 'N' character at the correct position.
            if (isWin8Plus == 1)
            {
                char first = result[0];
                int nIndex = Chars.IndexOf(first);
                result = result[1..].Insert(nIndex, "N");
            }

            // Format as XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
            result = string.Join("-",
                Enumerable.Range(0, 5).Select(i => result.Substring(i * 5, 5)));

            return IsValidFormat(result) ? result : null;
        }
        catch (UnauthorizedAccessException ex)
        {
            Debug.WriteLine($"[KeyExtractor] Registry access denied for DigitalProductId: {ex.Message}");
        }
        catch (System.Security.SecurityException ex)
        {
            Debug.WriteLine($"[KeyExtractor] Registry security error for DigitalProductId: {ex.Message}");
        }
        catch (ArgumentOutOfRangeException ex)
        {
            // DigitalProductId blob shorter than expected - can happen on unusual Windows editions.
            Debug.WriteLine($"[KeyExtractor] DigitalProductId blob malformed: {ex.Message}");
        }
        return null;
    }

    private static bool IsValidFormat(string key) =>
        Regex.IsMatch(key,
            @"^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$");
}
