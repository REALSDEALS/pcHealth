# pcHealth

A toolkit for IT technicians to check and repair Windows and Linux machines:
system and hardware information, SFC/DISM, battery reports, network tests,
updates, boot repair and more, from one menu.

![License](https://img.shields.io/github/license/REALSDEALS/pcHealth?label=License)
![Latest Release](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?label=Release)
![Pre-release](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?include_prereleases&label=Pre-release)
![Repo Size](https://img.shields.io/github/repo-size/REALSDEALS/pcHealth?label=Repo%20Size)

## Versions

| Platform | Terminal (CLI)       | Desktop app (GUI)        | Minimum                      |
|----------|----------------------|--------------------------|------------------------------|
| Windows  | PowerShell 7         | WinUI 3 (.NET 10)        | Windows 10 22H2 (build 19045) |
| Linux    | Python 3.11+         | GTK 4 + libadwaita       | Python 3.11                  |

The Windows tools run as Administrator. The Linux tools run as a normal user
and ask for the password (through `pkexec`) only for the actions that need
root.

## Windows

### Desktop app

Download from [Releases](https://github.com/REALSDEALS/pcHealth/releases):

- `pcHealth-<version>-win-x64.msi` (or `-win-arm64.msi`): installs to
  Program Files with a Start menu shortcut.
- `pcHealth-<version>-win-x64.zip` (or `-win-arm64.zip`): the same app,
  portable, for example on a USB stick.

Both are self-contained: the .NET runtime and Windows App SDK are included, so
nothing has to be installed on the machine first.

```powershell
# Unattended install
msiexec /i pcHealth-2.0.0-win-x64.msi /qn
```

![Health tab](Health-tab.avif)
![Tools tab](Tools-tab.avif)
![Programs tab](Programs-tab.avif)

### Terminal version

Download `pcHealth-CLI-<version>.zip` from Releases (it is not part of the MSI),
extract it and run `Start.ps1`, or run it from a clone of this repository:

```powershell
.\src\Windows\CLI\Start.ps1
```

`Start.ps1` also runs in Windows PowerShell 5.1. It checks the Windows build,
restarts itself as Administrator, offers to install PowerShell 7 through winget
when it is missing, and then opens the menu.

## Linux

Clone or download the repository, then:

```bash
cd src/Linux
python3 -m pchealth          # terminal menu
python3 -m pchealth.gui.app  # desktop app
```

The terminal menu needs only Python. The desktop app also needs PyGObject,
GTK 4 and libadwaita:

```bash
sudo dnf install python3-gobject gtk4 libadwaita         # Fedora / RHEL
sudo apt install python3-gi gir1.2-gtk-4.0 gir1.2-adw-1  # Debian / Ubuntu
sudo pacman -S python-gobject gtk4 libadwaita            # Arch
sudo zypper install python3-gobject gtk4 libadwaita      # openSUSE
```

Do not start the desktop app with `sudo`; it asks for elevation per action.
See [src/Linux/README.md](src/Linux/README.md) for details.

## Tools

The list comes from [assets/tools.json](assets/tools.json). Each platform
numbers its own entries, so the numbers differ between Windows and Linux.

### Windows

| Tool                        | What it does                                                        |
|-----------------------------|---------------------------------------------------------------------|
| System Information          | OS, build, firmware type, Secure Boot, TPM, RAM                     |
| Hardware Information        | CPU, GPU, RAM, chipset, disks (SMART through smartctl)              |
| Scan + Repair               | `sfc /scannow`, DISM CheckHealth/ScanHealth/RestoreHealth, `sfc` again |
| Battery Report              | `powercfg /batteryreport`                                            |
| Windows Update              | Opens Windows Update in Settings                                     |
| Disk Optimization           | Opens Optimize Drives (`dfrgui`)                                     |
| Disk Cleanup                | Opens Disk Cleanup (`cleanmgr`)                                      |
| Short Ping Test             | 4 pings to 8.8.8.8                                                   |
| Continuous Ping Test        | Pings 8.8.8.8 until you press Q, Esc or Ctrl+C                       |
| Traceroute to Google        | Route to google.com                                                  |
| Reset Network Stack         | Flushes DNS, renews DHCP, resets Winsock and TCP/IP (asks first)    |
| Update all packages         | `winget upgrade --all`                                               |
| Update HP Drivers           | Installs HP Image Assistant (HP devices only)                        |
| Restart Audio Drivers       | Restarts the Windows audio services                                  |
| Open Battery Report         | Opens the last generated report                                      |
| Open CBS Log                | Opens `C:\Windows\Logs\CBS\CBS.log` (the SFC/DISM log)               |
| Get Ninite                  | Downloads Ninite (Edge, Chrome, VLC, 7-Zip) and runs it if the signature is valid |
| Windows License Key         | Product key from the firmware (OA3) and the registry                |
| BIOS Password Recovery      | Opens [bios-pw.org](https://bios-pw.org) (by @bacher09)              |
| Boot Repair                 | UEFI only: `chkdsk /scan`, `sfc`, then `bcdboot` (see below)         |
| Shutdown / Reboot / Log Off | Normal shutdown, so apps can save their work                         |
| Repair Winget               | Reinstalls winget with [winget-install](https://github.com/asheroto/winget-install) by @asheroto |

The desktop app also has a Health overview and **Repair Windows**, which
starts Windows' own in-place repair (keeps files and apps).

### Linux

| Tool                        | What it does                                                        |
|-----------------------------|---------------------------------------------------------------------|
| System Information          | Distro, kernel, firmware, Secure Boot, RAM                           |
| Hardware Information        | CPU, GPU, RAM, disks (SMART through smartctl), sensors               |
| Short Ping Test             | 4 pings to 8.8.8.8                                                   |
| Continuous Ping Test        | Pings until stopped                                                  |
| Traceroute to Google        | `traceroute` / `tracepath`                                           |
| BIOS Password Recovery      | Opens [bios-pw.org](https://bios-pw.org)                             |
| Shutdown / Reboot / Log Off |                                                                     |
| Update all packages         | apt, dnf, pacman or zypper                                           |
| Topgrade                    | Runs [topgrade](https://github.com/topgrade-rs/topgrade) in a terminal |
| Battery Report              | Health, cycle count and power draw from sysfs                        |
| Scan + Repair               | Checks installed files against the package database                 |
| Disk Optimization           | `fstrim` on SSDs                                                     |
| Firmware Update             | fwupd / LVFS                                                         |
| Boot Repair                 | systemd-boot, GRUB or Limine on UEFI                                 |
| Disk Cleanup                | Package cache, journal, thumbnails; asks before removing packages   |
| Restart Audio               | Restarts PipeWire or PulseAudio                                      |
| Reset Network Stack         | Restarts NetworkManager and flushes the DNS cache                   |
| View System Logs            | Errors and warnings from `journalctl`, failed units                 |

On image-based systems (Fedora Silverblue, Bazzite, Kinoite) the tools that
change packages or boot files are hidden, because `/usr` is read-only there.

### Tools that change the system

- **Boot Repair** (Windows) rewrites the EFI boot files with `bcdboot`. It
  refuses legacy BIOS installs. It suspends BitLocker for one restart first;
  if that is not possible it stops before touching the boot files. Rewriting
  the boot files also puts Windows Boot Manager first in the firmware boot
  order, which matters on dual-boot machines.
- **Reset Network Stack** drops the connection (remote sessions disconnect)
  and can remove static IP and DNS settings.
- **Update all packages**, **Get Ninite** and **Update HP Drivers** install
  software.

## Programs menu

Installs, updates or opens common diagnostic tools.

| Windows (winget)        | Linux (package manager) |
|-------------------------|-------------------------|
| HWiNFO64                | htop                    |
| HWMonitor               | iotop                   |
| Malwarebytes AdwCleaner | smartmontools           |
| CrystalDiskInfo         | stress-ng               |
| CrystalDiskMark         | nmap                    |
| Prime95                 |                         |
| Windows PowerToys       |                         |

## Building

### Windows desktop app

Needs the [.NET 10 SDK](https://dotnet.microsoft.com/download). Visual Studio
2026 is optional.

```powershell
dotnet build src/Windows/GUI/pcHealth/pcHealth.csproj -c Debug -p:Platform=x64
pwsh -File src/Windows/GUI/Run-Debug.ps1   # build, run, and show the log in the terminal
```

The app must run as Administrator (see `app.manifest`), so starting it shows a
UAC prompt. Logs go to `%LOCALAPPDATA%\pcHealth`.

Release build (self-contained ZIPs, CLI ZIP and MSI). The MSI needs WiX 7:
`dotnet tool install --global wix --version 7.0.0`.

```powershell
pwsh -File development/tools/Build-Release.ps1 -Architecture x64
```

### Linux checks

```bash
cd src/Linux
python3 -m ruff check .
python3 -m ruff format --check .
python3 -m mypy pchealth
```

## Repository layout

| Path                 | Contents                                               |
|----------------------|--------------------------------------------------------|
| `src/Windows/CLI/`   | PowerShell 7 terminal tool (`Start.ps1`, menus, tools) |
| `src/Windows/GUI/`   | WinUI 3 desktop app                                    |
| `src/Linux/`         | Python package `pchealth`: terminal menu and GTK app   |
| `assets/tools.json`  | Tool list used by the Linux app; the Windows menus are kept in sync by hand |
| `assets/hardware-db.json` | CPU/GPU release years for the Health overview     |
| `installer/`         | WiX source for the MSI                                 |
| `development/tools/` | Build and maintenance scripts                          |

## Contributing

Open an issue before starting larger changes. Follow the conventions of the
part you change; [AGENTS.md](AGENTS.md) lists them per language.

A new tool is added to `assets/tools.json` first, then:

- Windows CLI: a `Verb-Noun.ps1` script in `src/Windows/CLI/tools/` and an
  entry in `src/Windows/CLI/menus/Tools.ps1`.
- Windows GUI: a page and view model, and an entry in `ToolsViewModel.cs`.
- Linux: a function in `src/Linux/pchealth/tools/` and an entry in `REGISTRY`
  in `pchealth/tools/__init__.py`. CI fails when `tools.json` lists a Linux
  tool that the registry cannot run.

Report security issues privately; see [SECURITY.md](SECURITY.md).

## Contact

Discord: **REALSDEALS**, or open an [issue](https://github.com/REALSDEALS/pcHealth/issues).

## License

[GNU GPL v3](LICENSE).

## History

pcHealth started as a batch script (`Scripts/CMD/pcHealth.bat`, still in the
git history). Version 2 replaced it with the PowerShell CLI, the WinUI app and
the Linux app, and merged these earlier projects into this repository:

- [pcHealthPlus](https://github.com/REALSDEALS/pcHealthPlus) and
  [pcHealthPlus-VS](https://github.com/REALSDEALS/pcHealthPlus-VS): PowerShell tools
- [pcHealth-GUI](https://github.com/iRepairzone-NL/pcHealth_GUI): Python GUI
- [Win_Scan](https://github.com/REALSDEALS/Win_Scan): SFC and DISM scanner
