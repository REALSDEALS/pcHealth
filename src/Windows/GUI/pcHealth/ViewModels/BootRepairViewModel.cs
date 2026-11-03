using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Management.Infrastructure;
using NLog;
using pcHealth.Services;
using System.Text;

namespace pcHealth.ViewModels;

// Same steps as src/Windows/CLI/tools/Invoke-BootRepair.ps1. bootrec.exe is
// not used: it only exists inside WinRE, and its /fixmbr and /fixboot steps
// write MBR boot code that a UEFI system never reads.
public partial class BootRepairViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();
    private readonly IProcessRunner _runner;

    [ObservableProperty] public partial string Output { get; set; } = "";
    [ObservableProperty] public partial string Status { get; set; } = "";
    [ObservableProperty] public partial bool IsRunning { get; set; }

    public BootRepairViewModel(IProcessRunner runner) => _runner = runner;

    [RelayCommand(CanExecute = nameof(CanRun), IncludeCancelCommand = true)]
    public async Task RunAsync(CancellationToken ct)
    {
        IsRunning = true;
        Output = "";
        Status = "Running boot repair…";

        var dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        void Append(string line) => dispatcher.TryEnqueue(() => Output += line + "\n");

        var system = Environment.SystemDirectory;
        var winDir = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        var winDrive = Path.GetPathRoot(winDir)!.TrimEnd('\\');

        try
        {
            if (!Helpers.Firmware.IsUefi())
            {
                Append("This system does not report UEFI firmware.");
                Append("pcHealth only repairs UEFI boot files. A legacy BIOS/MBR install needs recovery media and manual repair.");
                Status = "Not a UEFI system. Nothing was changed.";
                return;
            }

            Append($"[>>] Step 1/3: disk scan of {winDrive}");
            int chk = await _runner.RunAsync(Path.Combine(system, "chkdsk.exe"), $"{winDrive} /scan", Append, ct);
            if (chk != 0) Append($"[!!] chkdsk exited with code {chk}. Check its output above.");

            Append("\n[>>] Step 2/3: SFC");
            int sfc = await _runner.RunAsync(Path.Combine(system, "sfc.exe"), "/scannow", Append, ct,
                outputEncoding: Encoding.Unicode);
            if (sfc != 0) Append($"[!!] sfc exited with code {sfc}.");

            // Last point where Cancel applies; step 3 always runs to the end.
            ct.ThrowIfCancellationRequested();
            Append("\n[>>] Step 3/3: rewrite EFI boot files (bcdboot)");
            if (!await Task.Run(() => SuspendBitLocker(winDrive, Append)))
            {
                Append("[!!] Boot files left untouched: rewriting them with BitLocker active can lock the system behind its recovery key.");
                Append($"     Suspend BitLocker manually (manage-bde -protectors -disable {winDrive} -RebootCount 1) and run this again.");
                Status = "Stopped before the boot files. See details.";
                return;
            }

            if (await RewriteBootFilesAsync(system, winDir, Append))
            {
                Append("\n[OK] EFI boot files rewritten. Reboot the system to verify.");
                Status = "Done. Reboot required.";
            }
            else
            {
                Status = "Boot files were not rewritten. See details.";
            }
        }
        catch (OperationCanceledException)
        {
            Output += "\n[Cancelled]";
            Status = "Cancelled.";
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Boot repair failed");
            Output += $"\n[Error] {ex.Message}";
            Status = "Error.";
        }
        finally
        {
            IsRunning = false;
        }
    }

    private bool CanRun() => !IsRunning;

    // Rewriting the boot files changes what the TPM measures at boot, so a
    // BitLocker-protected laptop asks for its recovery key on the next start.
    // Suspending protection for one reboot avoids that; Windows resumes it
    // automatically. Returns true when it is safe to touch the boot files.
    private static bool SuspendBitLocker(string drive, Action<string> append)
    {
        const string ns = "root/cimv2/Security/MicrosoftVolumeEncryption";
        try
        {
            using var session = CimSession.Create(null);
            var volume = session.QueryInstances(ns, "WQL",
                $"SELECT * FROM Win32_EncryptableVolume WHERE DriveLetter='{drive}'").FirstOrDefault();

            // ProtectionStatus: 0 = off, 1 = on, 2 = unknown (volume locked).
            if (volume is null || volume.CimInstanceProperties["ProtectionStatus"]?.Value is uint status && status == 0)
                return true;

            using var args = new CimMethodParametersCollection
            {
                CimMethodParameter.Create("DisableCount", 1u, CimType.UInt32, CimFlags.In),
            };
            var result = session.InvokeMethod(ns, volume, "DisableKeyProtectors", args);
            if (result.ReturnValue?.Value is uint rv && rv == 0)
            {
                append($"[OK] BitLocker on {drive} suspended until the next restart.");
                return true;
            }
            append($"[!!] Could not suspend BitLocker on {drive} (return value {result.ReturnValue?.Value}).");
            return false;
        }
        catch (CimException ex) when (ex.NativeErrorCode == NativeErrorCode.InvalidNamespace)
        {
            // No BitLocker namespace means this edition has no BitLocker at all.
            return true;
        }
        catch (CimException ex)
        {
            Log.Warn(ex, "Could not read BitLocker state of {Drive}", drive);
            append($"[!!] Could not read the BitLocker state of {drive} -- {ex.Message}");
            return false;
        }
    }

    // Takes no CancellationToken on purpose: killing bcdboot halfway through
    // writing the boot files is worse than letting it finish.
    private async Task<bool> RewriteBootFilesAsync(string system, string winDir, Action<string> append)
    {
        // The EFI System Partition normally has no drive letter; mountvol /S
        // gives it one. Pick a letter that is really free, so an existing
        // drive is never targeted or dismounted.
        var used = DriveInfo.GetDrives().Select(d => char.ToUpperInvariant(d.Name[0])).ToHashSet();
        char free = Enumerable.Range('D', 'Z' - 'D' + 1).Select(c => (char)c).FirstOrDefault(c => !used.Contains(c));
        if (free == '\0')
        {
            append("[!!] No free drive letter to mount the EFI System Partition.");
            return false;
        }

        var mountvol = Path.Combine(system, "mountvol.exe");
        var esp = $"{free}:";
        if (await _runner.RunAsync(mountvol, $"{esp} /S", append) != 0)
        {
            append("[!!] Could not mount the EFI System Partition.");
            return false;
        }

        try
        {
            // /f UEFI, not /f ALL: ALL also writes BIOS boot files, which
            // nothing in the supported range boots from.
            int code = await _runner.RunAsync(Path.Combine(system, "bcdboot.exe"),
                $"\"{winDir}\" /s {esp} /f UEFI", append);
            if (code != 0) append($"[!!] bcdboot exited with code {code}.");
            return code == 0;
        }
        finally
        {
            // Always release the ESP, even when bcdboot failed.
            await _runner.RunAsync(mountvol, $"{esp} /D", append);
        }
    }
}
