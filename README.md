# pcHealth

Check the health of your Windows or Linux installation, drivers, updates, battery health and much more!

![License](https://img.shields.io/github/license/REALSDEALS/pcHealth?label=License)
![Latest Release](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?label=Release)
![Pre-release](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?include_prereleases&label=Pre-release)
![Repo Size](https://img.shields.io/github/repo-size/REALSDEALS/pcHealth?label=Repo%20Size)

---

## Overview

pcHealth is a cross-platform toolkit for IT technicians and power users. It runs on **Windows and Linux** using a single PowerShell 7 codebase. The goal is to offer the same functionality everywhere: tools are shown or hidden based on the detected OS, and platform-specific actions (like updating packages) automatically use the right method for the current system.

---

## Supported Platforms

| Platform | CLI | GUI | Minimum                       |
|----------|-----|-----|-------------------------------|
| Windows  | ✅  | ✅  | Build 26200 (Windows 11 25H2) |
| Linux    | ✅  | ❌  | Kernel 7.0                    |

pcHealth targets current systems only and exits immediately below the minimum. Everything in that range boots UEFI with GPT, which is why the repair tools are UEFI-only and no MBR/CSM paths remain.

On image-based systems (Fedora Silverblue, Bazzite, Kinoite, openSUSE MicroOS) the tools that manage packages or boot files are hidden rather than reimplemented: `/usr` is read-only and the bootloader belongs to the deployment, so `bootc` and `rpm-ostree` own that work. The other 14 Linux tools -- all the diagnostics -- run normally.

- Windows release info: https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information
- Linux kernel releases: https://www.kernel.org/

See [SECURITY.md](SECURITY.md) for version and end-of-life details.

---

## Getting Started

**Requirements:** PowerShell 7+, run as Administrator (Windows) or root/sudo (Linux). Minimum: Windows build 26200 (11 25H2) or Linux kernel 7.0.

### Windows

1. Download or clone this repository.
2. Run `Start.ps1` from an elevated PowerShell 7 terminal:

```powershell
.\src\CLI\Start.ps1
```

### Linux

**Requirements:** PowerShell 7 must be installed first (the launcher is a `.ps1` file — there is no bash wrapper). Install it via your package manager, e.g. `sudo pacman -S powershell` on Arch/CachyOS or see [aka.ms/powershell](https://aka.ms/powershell) for other distros.

1. Download or clone this repository.
2. Run `Start.ps1` elevated:

```bash
sudo pwsh src/CLI/Start.ps1
```

### GUI

On Windows, pcHealth includes a native desktop application built with **WinUI 3** (.NET 10). It provides the same functionality as the CLI in a graphical interface. Minimum: build 26200 (Windows 11 25H2).
![Health tab](Health-tab.avif)
![Tools tab](Tools-tab.avif)
![Programs tab](Programs-tab.avif)

A Linux GUI is not yet available - WinUI 3 is Windows-only. A cross-platform alternative is in the works.

**Build dependencies:**

| Tool | Install |
|------|---------|
| .NET 10 SDK | `winget install Microsoft.DotNet.SDK.10` |
| Visual Studio 2026 | `winget install Microsoft.VisualStudio.Community` |
| Windows App SDK | Included via NuGet on build |

```powershell
dotnet build "src/GUI/pcHealth/pcHealth.csproj" -c Release
```

Or open `src/GUI/pcHealth/pcHealth.csproj` in Visual Studio 2026.

---

## Menu Reference

All menus and option numbers are identical across platforms. Windows-only tools are hidden on Linux and vice versa, so numbers remain sequential with no gaps.

<details>
<summary><strong>Main Menu</strong></summary>

| Key | Option                 |
|-----|------------------------|
| 1   | Tools Menu             |
| 2   | Programs Menu          |
| 3   | Go to repository       |
| 4   | Check for pre-releases |
| 5   | Exit                   |

</details>

<details>
<summary><strong>Tools Menu</strong></summary>

Option numbers are assigned sequentially at runtime per platform - Windows-only tools are not shown on Linux and vice versa.

| Function                      | Platforms | Notes                                              |
|-------------------------------|-----------|----------------------------------------------------|
| System Information            | All       | OS, kernel, firmware, TPM, RAM                     |
| Hardware Information          | All       | CPU, GPU, Storage (SMART), RAM, Chipset, sensors   |
| Scan + Repair                 | Windows   | SFC + DISM combined                                |
| Battery Report                | Windows   | Laptop only                                        |
| Windows Update                | Windows   | Opens Windows Update settings                      |
| Disk Optimization             | Windows   | Opens dfrgui.exe                                   |
| Disk Cleanup                  | Windows   | Opens cleanmgr.exe                                 |
| Short Ping Test               | All       | 4-packet ping to 8.8.8.8                           |
| Continuous Ping Test          | All       | Continuous ping, Ctrl+C to stop                    |
| Traceroute to Google          | All       | tracert / traceroute                               |
| Reset Network Stack           | Windows   | DNS flush, Winsock reset, IPv4/IPv6 reset          |
| Update all packages           | Windows   | winget                                             |
| Update all packages           | Linux     | apt / dnf / pacman / zypper                        |
| Topgrade                      | Linux     | Full system upgrade: packages, flatpak, VS Code extensions, helm, uv, and more |
| Battery Report                | Linux     | Laptop only - health, cycles, draw from sysfs      |
| Scan + Repair                 | Linux     | Package integrity vs. package database             |
| Disk Optimization             | Linux     | fstrim on SSDs; Linux needs no defragmenting       |
| Firmware Update               | Linux     | fwupd / LVFS - BIOS, dock, SSD firmware            |
| Boot Repair                   | Linux     | systemd-boot / GRUB / Limine, UEFI - **care**      |
| Disk Cleanup                  | Linux     | Package cache, journal logs, unused Flatpak runtimes, thumbnail cache |
| Restart Audio                 | Linux     | Restarts PipeWire or PulseAudio user services      |
| Reset Network Stack           | Linux     | Restarts NetworkManager, flushes DNS cache         |
| Update HP Drivers             | Windows   | HP Image Assistant (HP devices only)               |
| Restart Audio Drivers         | Windows   | Restarts audio services                            |
| Open Battery Report           | Windows   | Opens previously generated report                  |
| Open CBS Log                  | Windows   | Opens C:\Windows\Logs\CBS\CBS.log                  |
| Get Ninite                    | Windows   | Downloads Edge, Chrome, VLC, 7-Zip                 |
| Windows License Key           | Windows   | OA3 + DigitalProductId registry decode             |
| BIOS Password Recovery        | All       | Links to bios-pw.org - credits: @bacher09          |
| Boot Repair                   | Windows   | CHKDSK + SFC + BCDBOOT, UEFI - **use with care**   |
| Shutdown / Reboot / Log Off   | All       |                                                    |
| Repair Winget                 | Windows   | via winget-install by @asheroto                    |
| View System Logs              | Linux     | journalctl errors/warnings, failed units           |

</details>

<details>
<summary><strong>Programs Menu - Windows</strong></summary>

| Key | Program                  | Install method |
|-----|--------------------------|----------------|
| 1   | HWiNFO64                 | winget         |
| 2   | HWMonitor                | winget         |
| 3   | Malwarebytes AdwCleaner  | winget         |
| 4   | CrystalDiskInfo          | winget         |
| 5   | CrystalDiskMark          | winget         |
| 6   | Prime95                  | winget         |
| 7   | Windows PowerToys        | winget         |

</details>

<details>
<summary><strong>Programs Menu - Linux</strong></summary>

Installed packages are marked `[installed]` in the menu.

| Key | Program       | Install method              |
|-----|---------------|-----------------------------|
| 1   | htop          | apt / dnf / pacman / zypper |
| 2   | iotop         | apt / dnf / pacman / zypper |
| 3   | smartmontools | apt / dnf / pacman / zypper |
| 4   | stress-ng     | apt / dnf / pacman / zypper |
| 5   | nmap          | apt / dnf / pacman / zypper |

</details>

---

## Contributing

Contributions are welcome. Follow the existing naming conventions: `Verb-Noun.ps1` for tools, consistent `Write-PcOption` / `Set-PcTheme` calls for UI.

- New tool scripts go in `src/CLI/tools/` and must be registered in `src/CLI/menus/Tools.ps1` with appropriate `Platforms` tags.
- Linux-only tools go in `src/CLI/tools/linux/`.
- Open an issue before starting larger changes to avoid duplicate work.

See [SECURITY.md](SECURITY.md) for responsible disclosure of vulnerabilities.

---

## Contact

Questions or feedback? Reach out on Discord: **REALSDEALS**

Or open an [issue](https://github.com/REALSDEALS/pcHealth/issues) on GitHub.

---

*Licensed under [GNU GPL v3](LICENSE). You are free to use this project, but you may not remove the attribution or re-license it.*

---

## Inspired by

This repository consolidates and replaces several earlier pcHealth-related projects. `pcHealth` is the original project and is now the canonical repository: related repositories have been migrated back into this repo and are considered deprecated. Functionality from the listed projects has been merged here where appropriate.

- [pcHealth](https://github.com/REALSDEALS/pcHealth) - original project (batch-based)
- [pcHealthPlus](https://github.com/REALSDEALS/pcHealthPlus) - PowerShell-based toolkit (deprecated; migrated)
- [pcHealthPlus-VS](https://github.com/REALSDEALS/pcHealthPlus-VS) - Visual Studio variant (deprecated; migrated)
- [pcHealth-GUI](https://github.com/iRepairzone-NL/pcHealth_GUI) - Python GUI variant (deprecated; migrated)
- [Win_Scan](https://github.com/REALSDEALS/Win_Scan) - standalone Windows scanning utility (deprecated; migrated)
