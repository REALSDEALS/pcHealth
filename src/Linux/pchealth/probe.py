"""Native readers for /proc, /sys and the standard library.

The kernel already publishes everything a health report needs. Asking lscpu,
uptime, findmnt, lsblk, timedatectl or mokutil for the same values means
spawning a process, hoping it is installed, and parsing prose that shifts with
the locale and the tool's version. These readers open the files those tools
open, so they work on a minimal install and inside a container, and they hand
back numbers instead of text.

What the kernel genuinely does not know stays on a command. PCI device *names*
live in hwdata's pci.ids, which is lspci's job, and SMART needs an ioctl, which
is smartctl's -- so those two keep their tools, with a sysfs fallback where one
is possible.
"""

from __future__ import annotations

import contextlib
import os
import re
import time
from dataclasses import dataclass, field
from pathlib import Path

from . import system

_CPU_ROOT = Path("/sys/devices/system/cpu")

# lspci prints "01:00.0 VGA compatible controller: NVIDIA ... [GeForce RTX 3060]".
_GPU_LINE = re.compile(
    r"^[\w:.]+\s+(?:VGA compatible controller|Display controller|3D controller):\s*(.+)$"
)

# The handful of vendors that ship a display adapter, for when pciutils is
# absent and only the numeric id from sysfs is available.
_PCI_VENDORS = {
    "0x1002": "AMD",
    "0x10de": "NVIDIA",
    "0x8086": "Intel",
    "0x102b": "Matrox",
    "0x1a03": "ASPEED",
    "0x1af4": "Virtio",
    "0x15ad": "VMware",
    "0x1234": "QEMU",
}

# Virtual devices: loopbacks, ramdisks, optical drives and mapper targets are
# not disks anyone wants a health row about.
_VIRTUAL_BLOCK = ("loop", "ram", "zram", "dm-", "sr", "md", "fd")


def _int(text: str | None) -> int | None:
    return int(text) if text and text.lstrip("-").isdigit() else None


# -- CPU ----------------------------------------------------------------------


@dataclass(frozen=True)
class Cpu:
    model: str = "Unknown"
    architecture: str = ""
    cores: int = 0
    threads: int = 0
    max_mhz: int | None = None
    virtualization: str = "None"
    # Level name ("L1d", "L2", ...) to size as the kernel spells it, per core.
    caches: dict[str, str] = field(default_factory=dict)
    # Names from /sys/.../vulnerabilities whose state starts with "Vulnerable".
    vulnerable: list[str] = field(default_factory=list)


def _cpu_fields() -> tuple[str, set[str], float | None]:
    """Model name, feature flags and the first reported clock from /proc/cpuinfo."""
    model = ""
    flags: set[str] = set()
    mhz: float | None = None
    for line in (system.read_text("/proc/cpuinfo") or "").splitlines():
        key, sep, value = line.partition(":")
        if not sep:
            continue
        key, value = key.strip(), value.strip()
        # x86 reports "model name"; arm64 has no such field and uses "Model".
        if not model and key in ("model name", "Model"):
            model = value
        elif not flags and key in ("flags", "Features"):
            flags = set(value.split())
        elif mhz is None and key == "cpu MHz":
            with contextlib.suppress(ValueError):
                mhz = float(value)
    return model, flags, mhz


def _caches() -> dict[str, str]:
    suffix = {"Data": "d", "Instruction": "i"}
    sizes: dict[str, str] = {}
    for index in sorted((_CPU_ROOT / "cpu0" / "cache").glob("index*")):
        level = system.read_text(index / "level")
        kind = system.read_text(index / "type") or ""
        size = system.read_text(index / "size")
        if level and size:
            sizes[f"L{level}{suffix.get(kind, '')}"] = size
    return sizes


def cpu() -> Cpu:
    """Everything lscpu reported, straight from procfs and the cpu sysfs tree."""
    model, flags, mhz = _cpu_fields()
    if not model:
        model = system.read_text("/sys/firmware/devicetree/base/model") or "Unknown"

    online = [entry for entry in _CPU_ROOT.glob("cpu[0-9]*") if entry.is_dir()]
    threads = len(online) or os.cpu_count() or 0
    cores = len(
        {
            (
                system.read_text(entry / "topology" / "physical_package_id"),
                system.read_text(entry / "topology" / "core_id"),
            )
            for entry in online
            if (entry / "topology" / "core_id").exists()
        }
    )

    max_khz = _int(system.read_text(_CPU_ROOT / "cpu0" / "cpufreq" / "cpuinfo_max_freq"))
    max_mhz = round(max_khz / 1000) if max_khz else (round(mhz) if mhz else None)

    if "vmx" in flags:
        virtualization = "VT-x"
    elif "svm" in flags:
        virtualization = "AMD-V"
    elif "hypervisor" in flags:
        virtualization = "Running as a guest"
    else:
        virtualization = "None"

    vulnerabilities = _CPU_ROOT / "vulnerabilities"
    vulnerable = (
        sorted(
            entry.name
            for entry in vulnerabilities.iterdir()
            if (system.read_text(entry) or "").startswith("Vulnerable")
        )
        if vulnerabilities.is_dir()
        else []
    )

    return Cpu(
        model=model,
        architecture=os.uname().machine,
        cores=cores or threads,
        threads=threads,
        max_mhz=max_mhz,
        virtualization=virtualization,
        caches=_caches(),
        vulnerable=vulnerable,
    )


def has_vulnerability_reporting() -> bool:
    return (_CPU_ROOT / "vulnerabilities").is_dir()


# -- Memory -------------------------------------------------------------------


def meminfo() -> dict[str, int]:
    """/proc/meminfo as kibibytes, keyed by its own labels."""
    values: dict[str, int] = {}
    for line in (system.read_text("/proc/meminfo") or "").splitlines():
        key, sep, rest = line.partition(":")
        if not sep:
            continue
        number = rest.strip().split(" ", 1)[0]
        if number.isdigit():
            values[key] = int(number)
    return values


# -- Uptime -------------------------------------------------------------------


def uptime_seconds() -> float | None:
    raw = (system.read_text("/proc/uptime") or "").split(" ", 1)[0]
    try:
        return float(raw)
    except ValueError:
        return None


def uptime_text() -> str:
    """The same phrasing `uptime -p` produces, without asking procps for it."""
    seconds = uptime_seconds()
    if seconds is None:
        return "Unknown"

    minutes = int(seconds // 60)
    parts = [
        (minutes // 1440, "day"),
        (minutes % 1440 // 60, "hour"),
        (minutes % 60, "minute"),
    ]
    said = [f"{n} {word}{'s' if n != 1 else ''}" for n, word in parts if n]
    return "up " + ", ".join(said) if said else "up less than a minute"


def boot_time_text() -> str:
    seconds = uptime_seconds()
    if seconds is None:
        return "Unknown"
    return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(time.time() - seconds))


# -- Mounts and disks ---------------------------------------------------------


@dataclass(frozen=True)
class Mount:
    target: str
    fstype: str
    source: str


def _unescape(text: str) -> str:
    """mountinfo octal-escapes space, tab, newline and backslash in paths."""
    return re.sub(r"\\([0-7]{3})", lambda match: chr(int(match.group(1), 8)), text)


def mounts() -> list[Mount]:
    """Every mount, from /proc/self/mountinfo -- the file findmnt reads."""
    found: list[Mount] = []
    for line in (system.read_text("/proc/self/mountinfo") or "").splitlines():
        # Optional fields sit between the mount point and " - ", so the line is
        # split on that separator rather than counted from the left.
        head, sep, tail = line.partition(" - ")
        fields, rest = head.split(), tail.split()
        if not sep or len(fields) < 5 or len(rest) < 2:
            continue
        found.append(Mount(_unescape(fields[4]), rest[0], _unescape(rest[1])))
    return found


def fstype_for(path: str) -> str | None:
    """The filesystem type of the mount that contains a path.

    The same answer `findmnt --target` gives: the longest mount point that is
    a prefix of the path wins, so a directory that is not itself a mount
    reports the filesystem it sits on.
    """
    target = os.path.realpath(path)
    best: Mount | None = None
    for mount in mounts():
        under = target == mount.target or target.startswith(mount.target.rstrip("/") + "/")
        if under and (best is None or len(mount.target) > len(best.target)):
            best = mount
    return best.fstype if best else None


@dataclass(frozen=True)
class BlockDevice:
    name: str
    size_bytes: int
    model: str
    rotational: bool | None

    @property
    def size_text(self) -> str:
        gb = self.size_bytes / 1000**3
        if gb >= 1000:
            return f"{gb / 1000:.1f} TB"
        return f"{gb:.1f} GB" if gb >= 1 else f"{self.size_bytes / 1000**2:.0f} MB"

    @property
    def kind(self) -> str:
        if self.rotational is None:
            return "Disk"
        return "HDD" if self.rotational else "SSD"


def block_devices() -> list[BlockDevice]:
    """Physical disks from /sys/block, the tree lsblk itself walks."""
    try:
        entries = sorted(Path("/sys/block").iterdir())
    except OSError:
        return []

    devices: list[BlockDevice] = []
    for entry in entries:
        if entry.name.startswith(_VIRTUAL_BLOCK):
            continue
        # The kernel always reports size in 512-byte sectors here, whatever the
        # drive's own block size is.
        sectors = _int(system.read_text(entry / "size")) or 0
        if not sectors:
            continue
        model = (
            system.read_text(entry / "device" / "model")
            or system.read_text(entry / "device" / "name")
            or ""
        )
        rotational = _int(system.read_text(entry / "queue" / "rotational"))
        devices.append(
            BlockDevice(
                name=entry.name,
                size_bytes=sectors * 512,
                model=model.strip(),
                rotational=None if rotational is None else bool(rotational),
            )
        )
    return devices


# -- Graphics -----------------------------------------------------------------


def gpus() -> list[str]:
    """Display adapters by name.

    Product names are not in the kernel: sysfs has the numeric PCI id and
    hwdata's pci.ids turns it into words, which is precisely what lspci does.
    So the name comes from lspci when pciutils is installed, and from the
    vendor id and driver the kernel does know when it is not -- rather than
    reporting nothing at all, which is what the old lspci-only path did.
    """
    listing = system.output(["lspci"])
    if listing is not None:
        named = [
            match.group(1).strip()
            for line in listing.splitlines()
            if (match := _GPU_LINE.match(line))
        ]
        if named:
            return named
    return _gpus_from_drm()


def _gpus_from_drm() -> list[str]:
    found: list[str] = []
    try:
        cards = sorted(Path("/sys/class/drm").glob("card[0-9]*"))
    except OSError:
        return found

    for card in cards:
        # card0-HDMI-A-1 is a connector on card0, not a second adapter.
        if "-" in card.name:
            continue
        device = card / "device"
        vendor = system.read_text(device / "vendor") or ""
        label = _PCI_VENDORS.get(vendor, f"PCI vendor {vendor}" if vendor else "Unknown vendor")
        driver = device / "driver"
        name = os.path.basename(os.readlink(driver)) if driver.is_symlink() else ""
        found.append(f"{label} graphics ({name})" if name else f"{label} graphics")
    return found


# -- Firmware and locale ------------------------------------------------------


def secure_boot() -> str:
    """Enabled, Disabled or Unknown, from the EFI variable mokutil reads.

    The first four bytes of an efivars entry are the variable's attributes;
    the fifth is the flag. Going here directly means the answer does not
    depend on mokutil being installed.
    """
    efivars = Path("/sys/firmware/efi/efivars")
    try:
        names = [entry for entry in efivars.iterdir() if entry.name.startswith("SecureBoot-")]
    except OSError:
        return "Unknown"

    for entry in names:
        try:
            raw = entry.read_bytes()[:5]
        except OSError:
            continue
        if len(raw) == 5:
            return "Enabled" if raw[4] else "Disabled"
    return "Unknown"


def timezone() -> str:
    """The zone name, from the /etc/localtime symlink systemd itself sets."""
    link = Path("/etc/localtime")
    if link.is_symlink():
        _, sep, zone = os.readlink(link).partition("zoneinfo/")
        if sep and zone:
            return zone
    return system.read_text("/etc/timezone") or os.environ.get("TZ") or time.tzname[0] or "N/A"
