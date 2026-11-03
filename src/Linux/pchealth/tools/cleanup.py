"""Disk cleanup, SSD trim and the package-integrity scan."""

from __future__ import annotations

from pathlib import Path

from .. import system
from .base import Level, ToolUI

FS_ERROR_PATTERNS = ("EXT4-fs error", "XFS", "BTRFS error", "I/O error", "read-only")
MAX_FINDINGS_SHOWN = 20

Step = tuple[str, list[str]]

_ARCH = ("arch", "cachyos", "manjaro", "endeavouros", "artix", "garuda")
_DEBIAN = ("debian", "ubuntu", "mint", "pop", "elementary", "zorin", "kali")
_FEDORA = ("fedora", "rhel", "centos", "almalinux", "rocky")


# -- Disk cleanup -------------------------------------------------------------


def _cache_steps(ui: ToolUI, family: str) -> list[Step]:
    """Package-cache cleanup. Removes no installed software."""
    if any(key in family for key in _ARCH):
        if system.has("paccache"):
            return [("Clearing pacman cache (keeping 2 versions)", ["paccache", "-rk2"])]
        return []
    if any(key in family for key in _DEBIAN):
        return [("Cleaning apt cache", ["apt", "autoclean"])]
    if any(key in family for key in _FEDORA):
        return [("Cleaning dnf cache", ["dnf", "clean", "all"])]
    if "suse" in family:
        return [("Cleaning zypper cache", ["zypper", "clean", "--all"])]

    ui.note("Package cache: distro not recognised, skipping.")
    return []


def _removal_steps(family: str) -> tuple[list[Step], list[str]]:
    """Steps that uninstall packages, plus the names that will go when known.

    These are kept apart so the user sees the list and agrees first.
    """
    if any(key in family for key in _ARCH):
        # Passing an empty list to pacman -Rs exits non-zero and reads like a
        # failure, so only run it when there is something to remove. -n is
        # left out on purpose: it also deletes the saved config files.
        orphans = (system.output(["pacman", "-Qdtq"]) or "").split()
        if not orphans:
            return [], []
        argv = ["pacman", "-Rs", *orphans, "--noconfirm"]
        return [("Removing unneeded dependencies", argv)], orphans

    if any(key in family for key in _DEBIAN):
        # A dry run lists what autoremove would take; "Remv" is not translated.
        simulated = system.run(["apt-get", "-s", "autoremove"]).stdout
        names = [line.split()[1] for line in simulated.splitlines() if line.startswith("Remv ")]
        if not names:
            return [], []
        return [("Removing unneeded apt packages", ["apt", "autoremove", "-y"])], names

    if any(key in family for key in _FEDORA):
        # dnf has no stable dry-run listing, so the confirmation names the
        # step rather than the packages.
        return [("Removing unneeded dnf packages", ["dnf", "autoremove", "-y"])], []

    return [], []


def _clear_thumbnails(ui: ToolUI) -> None:
    """Runs unprivileged: the cache belongs to the user, not to root."""
    user = system.desktop_user()
    thumbnails = Path(user.home) / ".cache" / "thumbnails" if user else None
    if not thumbnails or not thumbnails.is_dir():
        return

    files = [path for path in thumbnails.rglob("*") if path.is_file()]
    size_mb = sum(path.stat().st_size for path in files) / 1048576 if files else 0.0

    step = ui.step(f"Clearing thumbnail cache ({size_mb:.1f} MB)")
    removed = 0
    for path in files:
        try:
            path.unlink()
            removed += 1
        except OSError:
            continue
    step.finish(True, f"Removed {removed} file(s)")


def disk_cleanup(ui: ToolUI) -> None:
    info = system.distro_info()
    ui.section(f"Disk Cleanup on {info['PRETTY_NAME']}")

    family = f"{info['ID']} {info['ID_LIKE']}"
    steps = _cache_steps(ui, family)
    if system.has("journalctl"):
        steps.append(("Vacuuming journal (keeping 7 days)", ["journalctl", "--vacuum-time=7d"]))

    removals, packages = _removal_steps(family)
    if system.has("flatpak"):
        removals.append(("Removing unused Flatpaks", ["flatpak", "uninstall", "--unused", "-y"]))
    if removals:
        if packages:
            ui.note(f"{len(packages)} package(s) are no longer needed:")
            ui.note(", ".join(packages[:MAX_FINDINGS_SHOWN]))
            if len(packages) > MAX_FINDINGS_SHOWN:
                ui.note(f"... and {len(packages) - MAX_FINDINGS_SHOWN} more.")
        question = (
            "Also uninstall software nobody depends on? ("
            + "; ".join(label for label, _ in removals)
            + ")"
        )
        if ui.confirm(question):
            steps.extend(removals)
        else:
            ui.note("Skipping package removal; cleaning caches only.")

    ui.run_all(steps, root=True)
    _clear_thumbnails(ui)
    ui.note("Disk cleanup complete.", Level.OK)


# -- Disk optimization --------------------------------------------------------


def _block_devices() -> list[tuple[str, str]]:
    """Real disks and whether they spin, skipping loop/ram/zram/optical."""
    try:
        entries = sorted(Path("/sys/block").iterdir())
    except OSError:
        return []
    return [
        (
            entry.name,
            {"0": "SSD / NVMe", "1": "HDD"}.get(
                system.read_text(entry / "queue" / "rotational") or "", "Unknown"
            ),
        )
        for entry in entries
        if not entry.name.startswith(("loop", "ram", "zram", "sr"))
    ]


def disk_optimize(ui: ToolUI) -> None:
    ui.section("Disk Optimization")

    # Linux filesystems do not fragment the way NTFS does, so the useful half
    # of what dfrgui does on Windows is discarding unused blocks on an SSD.
    devices = _block_devices()
    if devices:
        ui.fields(devices)
        if not any(kind == "SSD / NVMe" for _, kind in devices):
            ui.note("No solid-state device detected -- there is nothing to trim.", Level.WARN)
            ui.note("Linux filesystems do not need defragmenting.")
            return

    if not system.has("fstrim"):
        ui.note("fstrim not found. Install util-linux.", Level.ERROR)
        return

    # Many distros already run fstrim.timer weekly; say so rather than
    # implying the manual run was necessary.
    if system.output(["systemctl", "is-enabled", "fstrim.timer"]) == "enabled":
        ui.note("fstrim.timer is enabled, so this already runs weekly.")

    ui.run(
        ["fstrim", "--all", "--verbose"],
        label="Trimming mounted filesystems",
        root=True,
        ok="Trim complete",
    )


# -- Scan + repair ------------------------------------------------------------


def scan_repair(ui: ToolUI) -> None:
    ui.section("Scan + Repair")

    manager = system.package_manager()
    if not manager or not manager.verify:
        ui.note("No supported package manager found (apt/dnf/pacman/zypper).", Level.ERROR)
        return

    verify_cmd, *verify_args = manager.verify
    if not system.has(verify_cmd):
        ui.note(
            f"{verify_cmd} is not installed -- it does the checking, not {manager.cmd}.",
            Level.ERROR,
        )
        ui.note(f"Install it with: {manager.cmd} {' '.join(manager.install)} {verify_cmd}")
        return

    # Read-only on purpose: fsck cannot safely touch a mounted root, so report
    # what the kernel already saw and let the user repair from a live image.
    dmesg = ui.run(["dmesg", "--level=err,warn"], label="Checking the kernel log", root=True)
    fs_errors = [
        line
        for line in dmesg.stdout.splitlines()
        if any(pattern in line for pattern in FS_ERROR_PATTERNS)
    ]
    if fs_errors:
        ui.note(f"The kernel has logged {len(fs_errors)} filesystem error(s).", Level.ERROR)
        ui.fields([(f"Line {n}", line) for n, line in enumerate(fs_errors[-10:], 1)])
        ui.note("Run fsck from a live image -- it cannot repair a mounted root.", Level.WARN)
    else:
        ui.note("No filesystem errors in the kernel log.", Level.OK)

    if not ui.confirm(f"Verify every packaged file with {verify_cmd}? This takes several minutes."):
        return

    # Merge stderr: debsums reports every changed file there, so dropping it
    # would turn a corrupted system into a clean bill of health.
    verify = ui.run(
        [verify_cmd, *verify_args],
        label=f"Verifying packages with {verify_cmd}",
        root=True,
        ok="Verified",
    )
    findings = [line.strip() for line in verify.stdout.splitlines() if line.strip()]

    if not findings:
        ui.note("Every packaged file matches the package database.", Level.OK)
        return

    ui.section(f"{len(findings)} file(s) no longer match their package")
    ui.fields(
        [(line.split()[-1], " ".join(line.split()[:-1])) for line in findings[:MAX_FINDINGS_SHOWN]]
    )
    if len(findings) > MAX_FINDINGS_SHOWN:
        ui.note(f"... and {len(findings) - MAX_FINDINGS_SHOWN} more.")
    ui.note("Config files you edited yourself show up here too -- that is expected.")
    ui.note(f"Repair with: {manager.cmd} {' '.join(manager.install)} --reinstall <package>")
