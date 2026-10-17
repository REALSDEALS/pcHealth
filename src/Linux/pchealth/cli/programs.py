"""The Programs menu: install the diagnostic packages a technician wants."""

from __future__ import annotations

from dataclasses import dataclass

from .. import system
from . import theme


@dataclass(frozen=True)
class Package:
    name: str
    package: str
    # What the menu probes for the [installed] marker: one PATH lookup instead
    # of a different "is this present" query per package manager.
    binary: str
    note: str


PACKAGES: tuple[Package, ...] = (
    Package("htop", "htop", "htop", "process viewer"),
    Package("iotop", "iotop", "iotop", "I/O monitor"),
    Package("smartmontools", "smartmontools", "smartctl", "disk SMART data"),
    Package("stress-ng", "stress-ng", "stress-ng", "stress test"),
    Package("nmap", "nmap", "nmap", "network scanner"),
)


def show() -> str:
    """Run the Programs menu. Returns the next screen: main, tools or exit."""
    manager = system.package_manager()

    while True:
        theme.header("Programs")

        if system.is_image_based():
            theme.write("This is an image-based system (ostree).", "warn")
            theme.write("Install these with Homebrew, Distrobox or a Flatpak instead:", "warn")
            theme.write("  brew install htop      # or: distrobox enter", "muted")
            theme.write()
        elif not manager:
            theme.write("No supported package manager found (apt/dnf/pacman/zypper).", "error")
            theme.write()

        for index, package in enumerate(PACKAGES, start=1):
            marker = "[installed]" if system.has(package.binary) else ""
            theme.option(str(index), f"{package.name}  ({package.note})", marker)

        theme.write()
        nav_tools = len(PACKAGES) + 1
        nav_main = len(PACKAGES) + 2
        nav_exit = len(PACKAGES) + 3
        theme.option(str(nav_tools), "Tools Menu")
        theme.option(str(nav_main), "Back to Main Menu")
        theme.option(str(nav_exit), "Exit")
        theme.write()

        choice = input("  Choice: ").strip()
        if not choice.isdigit():
            theme.write("Invalid choice.", "error")
            continue

        number = int(choice)
        if number == nav_tools:
            return "tools"
        if number == nav_main:
            return "main"
        if number == nav_exit:
            return "exit"
        if not 1 <= number <= len(PACKAGES):
            theme.write("Invalid choice.", "error")
            continue

        package = PACKAGES[number - 1]
        if system.has(package.binary):
            theme.write(f"{package.name} is already installed.", "ok")
            input("\n  Press Enter to continue...")
            continue
        if not manager or system.is_image_based():
            theme.write(f"Cannot install {package.name} on this system.", "error")
            input("\n  Press Enter to continue...")
            continue

        theme.write()
        theme.write(f"[>>] Installing {package.name}...", "accent")
        rc = system.stream_root(
            [manager.cmd, *manager.install, package.package],
            lambda line: theme.write(f"  {line}", "muted"),
        )
        theme.write()
        if rc == 0:
            theme.write(f"[OK] {package.name} installed.", "ok")
        else:
            theme.write(f"[!!] Installation exited with code {rc}.", "error")
        input("\n  Press Enter to continue...")
