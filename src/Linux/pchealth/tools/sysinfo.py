"""System information, and the BIOS password link."""

from __future__ import annotations

import os
import socket

from .. import probe, system
from .base import Choice, Level, ToolUI

_SECURE_BOOT_NOTE = (
    "Secure Boot shows the UEFI firmware state only. Actual enforcement "
    "depends on shim/MOK setup and varies per distro."
)


def _machine_model() -> str:
    vendor = system.read_text("/sys/class/dmi/id/sys_vendor")
    model = system.read_text("/sys/class/dmi/id/product_name")
    if vendor and model:
        return f"{vendor} {model}"
    return model or "N/A"


def _package_count() -> str:
    for command, argv, label in (
        ("pacman", ["pacman", "-Q"], "pacman"),
        ("dpkg", ["dpkg-query", "-f", "${binary:Package}\n", "-W"], "dpkg"),
        ("rpm", ["rpm", "-qa"], "rpm"),
    ):
        if not system.has(command):
            continue
        listing = system.output(argv)
        if listing is not None:
            return f"{len(listing.splitlines())} ({label})"
    return "N/A"


def _session_type() -> str:
    if os.environ.get("WAYLAND_DISPLAY"):
        return "Wayland"
    if os.environ.get("DISPLAY"):
        return "X11"
    return "Unknown"


def system_info(ui: ToolUI) -> None:
    ui.section("System Information")

    memory = probe.meminfo()
    total_kib = memory.get("MemTotal")
    available_kib = memory.get("MemAvailable")
    uname = os.uname()
    user = system.desktop_user()

    ui.fields(
        [
            ("Computer name", socket.gethostname()),
            ("Machine", _machine_model()),
            ("OS name", system.distro_info()["PRETTY_NAME"]),
            ("Kernel", uname.release),
            ("Architecture", uname.machine),
            ("CPU", probe.cpu().model),
            (
                "RAM used",
                f"{(total_kib - available_kib) / 1048576:.2f} GB"
                if total_kib and available_kib is not None
                else "N/A",
            ),
            ("RAM total", f"{total_kib / 1048576:.2f} GB" if total_kib else "N/A"),
            ("Firmware", "UEFI" if os.path.exists("/sys/firmware/efi") else "Legacy BIOS"),
            ("Secure Boot", probe.secure_boot()),
            ("Uptime", probe.uptime_text()),
            ("Last boot", probe.boot_time_text()),
            (
                "Desktop",
                os.environ.get("XDG_CURRENT_DESKTOP")
                or os.environ.get("DESKTOP_SESSION")
                or "Unknown",
            ),
            ("Session", _session_type()),
            ("Shell", os.environ.get("SHELL", "Unknown").rsplit("/", 1)[-1]),
            ("Packages", _package_count()),
            ("Timezone", probe.timezone()),
            ("User", user.name if user else "N/A"),
        ]
    )
    ui.note(_SECURE_BOOT_NOTE)


def bios_password(ui: ToolUI) -> None:
    """Links to bios-pw.org. Credits: @bacher09 -- pwgen-for-bios."""
    ui.section("BIOS Password Recovery")
    ui.note(
        "bios-pw.org generates recovery codes for locked BIOS passwords. "
        "Credits for this tool go to @bacher09."
    )

    urls = {
        "site": "https://bios-pw.org",
        "repo": "https://github.com/bacher09/pwgen-for-bios",
    }
    choice = ui.choose(
        "Which page should open?",
        [
            Choice("site", "bios-pw.org", "The recovery tool itself"),
            Choice("repo", "pwgen-for-bios on GitHub", "How the codes are generated"),
        ],
    )
    if choice is None:
        return

    if not system.open_url(urls[choice]):
        ui.note(f"Could not open a browser. Visit: {urls[choice]}", Level.WARN)
