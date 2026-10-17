"""The health report.

The Linux counterpart of the WinUI 3 Health page: a handful of sections, each
a list of checks, each check carrying a status so a front-end can colour it.
The gathering lives here; the terminal and the GTK window only render it.

What is checked differs from Windows because the systems differ -- there is no
Defender or BitLocker here, but there are CPU mitigations, a firewall, an LSM
and a package count. The shape of the answer is the same.
"""

from __future__ import annotations

import json
import shutil
from dataclasses import dataclass, field
from enum import Enum
from functools import lru_cache
from pathlib import Path

from . import probe, smart, system


class Status(Enum):
    GOOD = "good"
    WARNING = "warning"
    BAD = "bad"
    UNKNOWN = "unknown"
    INFO = "info"


_PSEUDO_FILESYSTEMS = frozenset(
    {
        "",
        "autofs",
        "binfmt_misc",
        "bpf",
        "cgroup",
        "cgroup2",
        "configfs",
        "debugfs",
        "devpts",
        "devtmpfs",
        "efivarfs",
        "fusectl",
        "hugetlbfs",
        "mqueue",
        "overlay",
        "proc",
        "pstore",
        "ramfs",
        "securityfs",
        "squashfs",
        "sysfs",
        "tmpfs",
        "tracefs",
    }
)

# Worst-first, so a section takes the colour of its most serious finding.
_SEVERITY = {Status.BAD: 4, Status.WARNING: 3, Status.UNKNOWN: 2, Status.GOOD: 1, Status.INFO: 0}


@dataclass(frozen=True)
class Check:
    label: str
    value: str
    status: Status = Status.INFO
    detail: str = ""


@dataclass(frozen=True)
class Section:
    title: str
    checks: list[Check] = field(default_factory=list)

    @property
    def status(self) -> Status:
        if not self.checks:
            return Status.UNKNOWN
        return max((check.status for check in self.checks), key=lambda s: _SEVERITY[s])


# -- Shared hardware database -------------------------------------------------


@lru_cache(maxsize=1)
def _hardware_db() -> dict[str, list[dict[str, object]]]:
    """The same assets/hardware-db.json the WinUI 3 Health page reads."""
    for candidate in (
        Path(__file__).resolve().parent / "hardware-db.json",
        Path(__file__).resolve().parents[3] / "assets" / "hardware-db.json",
    ):
        try:
            data = json.loads(candidate.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        return {key: value for key, value in data.items() if isinstance(value, list)}
    return {}


def _release_year(name: str, table: str, key: str) -> int | None:
    for entry in _hardware_db().get(table, []):
        needle = str(entry.get(key, ""))
        if needle and needle.lower() in name.lower():
            year = entry.get("year")
            return int(year) if isinstance(year, int) else None
    return None


def _age_status(year: int | None, *, warn_after: int = 7, bad_after: int = 10) -> Status:
    if year is None:
        return Status.UNKNOWN
    from datetime import date

    age = date.today().year - year
    if age >= bad_after:
        return Status.WARNING if age < bad_after + 5 else Status.BAD
    return Status.WARNING if age >= warn_after else Status.GOOD


# -- Sections -----------------------------------------------------------------


def _overview() -> Section:
    info = system.distro_info()
    vendor = system.read_text("/sys/class/dmi/id/sys_vendor")
    model = system.read_text("/sys/class/dmi/id/product_name")
    uefi = Path("/sys/firmware/efi").exists()

    checks = [
        Check("Distribution", info["PRETTY_NAME"]),
        Check("Kernel", system.kernel_release(), Status.GOOD),
        Check("Machine", f"{vendor} {model}" if vendor and model else model or "Unknown"),
        Check(
            "Firmware",
            "UEFI" if uefi else "Legacy BIOS",
            Status.GOOD if uefi else Status.WARNING,
            "" if uefi else "Boot Repair only supports UEFI systems.",
        ),
        Check("Uptime", probe.uptime_text()),
    ]
    if system.is_image_based():
        checks.append(
            Check(
                "Deployment",
                "Image-based (ostree)",
                Status.INFO,
                "Package and boot tools are hidden.",
            )
        )
    return Section("Overview", checks)


def _cpu() -> Section:
    info = probe.cpu()
    year = _release_year(info.model, "cpu_models", "name")
    checks = [
        Check(
            "Processor",
            info.model,
            _age_status(year),
            f"Released {year}" if year else "Not in the hardware database",
        ),
        Check("Cores / threads", f"{info.cores} / {info.threads}"),
    ]

    # Mitigations are the closest Linux equivalent of the Windows security rows.
    if probe.has_vulnerability_reporting():
        checks.append(
            Check(
                "CPU mitigations",
                "All mitigated" if not info.vulnerable else f"{len(info.vulnerable)} vulnerable",
                Status.GOOD if not info.vulnerable else Status.WARNING,
                ", ".join(info.vulnerable),
            )
        )
    return Section("Processor", checks)


def _graphics() -> Section:
    checks = []
    for name in probe.gpus():
        year = _release_year(name, "gpu_series", "pattern")
        checks.append(Check("GPU", name, _age_status(year), f"Released {year}" if year else ""))
    return Section("Graphics", checks or [Check("GPU", "None detected", Status.UNKNOWN)])


def _memory() -> Section:
    values = probe.meminfo()
    total = values.get("MemTotal", 0)
    if not total:
        return Section("Memory", [Check("RAM", "Not readable", Status.UNKNOWN)])

    available = values.get("MemAvailable", 0)
    used_pct = round((total - available) / total * 100)
    swap_total = values.get("SwapTotal", 0)

    return Section(
        "Memory",
        [
            Check(
                "RAM",
                f"{total / 1048576:.1f} GB total, {used_pct}% in use",
                Status.BAD if used_pct >= 95 else Status.WARNING if used_pct >= 85 else Status.GOOD,
            ),
            Check(
                "Swap",
                f"{swap_total / 1048576:.1f} GB" if swap_total else "None configured",
                Status.INFO if swap_total else Status.WARNING,
            ),
        ],
    )


def _storage() -> Section:
    checks: list[Check] = []

    for device in smart.devices():
        status = (
            Status.GOOD
            if device.passed
            else Status.BAD
            if device.passed is False
            else Status.UNKNOWN
        )
        detail = []
        if device.life_left_pct is not None:
            detail.append(f"life {device.life_left_pct}%")
            if device.life_left_pct < 20:
                status = Status.WARNING if status is Status.GOOD else status
        if device.temperature_c is not None:
            detail.append(f"{device.temperature_c} C")
        if device.power_on_hours is not None:
            detail.append(f"{device.power_on_hours} h")
        checks.append(Check(device.model, device.health_text, status, ", ".join(detail)))

    if not checks and not smart.available():
        checks.append(
            Check(
                "SMART",
                "smartmontools not installed",
                Status.UNKNOWN,
                "No disk health data available.",
            )
        )

    # Filesystem usage: the thing that actually breaks a machine day to day.
    seen: set[int] = set()
    for mount in probe.mounts():
        if mount.fstype in _PSEUDO_FILESYSTEMS:
            continue
        try:
            usage = shutil.disk_usage(mount.target)
        except OSError:
            continue
        # Bind mounts and container overlays repeat the same device, and a
        # sub-gigabyte mount is a boot partition or a container detail, not
        # something anyone needs a health warning about.
        if usage.total in seen or usage.total < 1024**3:
            continue
        seen.add(usage.total)
        used_pct = round(usage.used / usage.total * 100) if usage.total else 0
        free_gb = usage.free / 1024**3
        total_gb = usage.total / 1024**3
        checks.append(
            Check(
                f"Free space on {mount.target}",
                f"{free_gb:.0f} GB free of {total_gb:.0f} GB ({used_pct}% used)",
                Status.BAD if used_pct >= 95 else Status.WARNING if used_pct >= 85 else Status.GOOD,
            )
        )

    return Section("Storage", checks)


def _battery() -> Section | None:
    root = Path("/sys/class/power_supply")
    if not root.is_dir():
        return None

    for entry in sorted(root.iterdir()):
        if system.read_text(entry / "type") != "Battery":
            continue

        full = system.read_text(entry / "energy_full") or system.read_text(entry / "charge_full")
        design = system.read_text(entry / "energy_full_design") or system.read_text(
            entry / "charge_full_design"
        )
        checks = [
            Check("Status", system.read_text(entry / "status") or "Unknown"),
            Check("Charge", f"{system.read_text(entry / 'capacity') or '?'}%"),
        ]
        try:
            if full and design and float(design) > 0:
                health = round(float(full) / float(design) * 100, 1)
                checks.append(
                    Check(
                        "Health",
                        f"{health}% of design capacity",
                        Status.GOOD
                        if health >= 80
                        else Status.WARNING
                        if health >= 60
                        else Status.BAD,
                    )
                )
        except ValueError:
            pass

        cycles = system.read_text(entry / "cycle_count")
        checks.append(Check("Cycle count", cycles or "Not reported by driver"))
        return Section("Battery", checks)

    return None


def _security() -> Section:
    checks: list[Check] = []

    state = probe.secure_boot()
    checks.append(
        Check(
            "Secure Boot",
            state,
            Status.GOOD
            if state == "Enabled"
            else Status.WARNING
            if state == "Disabled"
            else Status.UNKNOWN,
            "" if state != "Unknown" else "No EFI SecureBoot variable on this system.",
        )
    )

    tpm = Path("/sys/class/tpm/tpm0")
    version = system.read_text(tpm / "tpm_version_major") if tpm.is_dir() else None
    checks.append(
        Check(
            "TPM",
            f"Present (TPM {version})" if version else "Present" if tpm.is_dir() else "Not present",
            Status.GOOD if tpm.is_dir() else Status.INFO,
        )
    )

    lsm = system.read_text("/sys/kernel/security/lsm") or ""
    active = [name for name in ("selinux", "apparmor") if name in lsm]
    checks.append(
        Check(
            "Access control",
            ", ".join(name.upper() for name in active) if active else "None active",
            Status.GOOD if active else Status.WARNING,
        )
    )

    for command, argv, good in (
        ("firewall-cmd", ["firewall-cmd", "--state"], "running"),
        ("ufw", ["ufw", "status"], "active"),
    ):
        if not system.has(command):
            continue
        # Deliberately unprivileged: a report that asks for the root password
        # to tell you the firewall state is not worth the interruption. Where
        # the query needs root, say so rather than prompting.
        result = system.run(argv)
        output = (result.stdout + result.stderr).lower()
        if good in output:
            checks.append(Check("Firewall", f"{command}: active", Status.GOOD))
        elif result.ok:
            checks.append(Check("Firewall", f"{command}: inactive", Status.WARNING))
        else:
            checks.append(Check("Firewall", command, Status.UNKNOWN, "State needs root to query."))
        break
    else:
        checks.append(Check("Firewall", "No firewall tool found", Status.UNKNOWN))

    return Section("Security", checks)


def _services() -> Section:
    if not system.has("systemctl"):
        return Section("Services", [Check("systemd", "Not in use", Status.INFO)])

    failed = system.output(["systemctl", "--failed", "--no-legend", "--no-pager"]) or ""
    count = len([line for line in failed.splitlines() if line.strip()])
    checks = [
        Check(
            "Failed units",
            "None" if not count else f"{count} failed",
            Status.GOOD if not count else Status.WARNING,
            failed.strip()[:200],
        )
    ]

    boot = system.output(["systemd-analyze", "time"])
    if boot:
        checks.append(Check("Boot time", boot.splitlines()[0]))
    return Section("Services", checks)


def collect() -> list[Section]:
    """Every section, in the order both front-ends show them."""
    sections = [_overview(), _cpu(), _graphics(), _memory(), _storage()]
    battery = _battery()
    if battery:
        sections.append(battery)
    sections += [_security(), _services()]
    return sections


def overall(sections: list[Section]) -> Status:
    if not sections:
        return Status.UNKNOWN
    return max((section.status for section in sections), key=lambda s: _SEVERITY[s])
