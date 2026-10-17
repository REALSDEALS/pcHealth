"""Package updates: the distro's own manager, and topgrade."""

from __future__ import annotations

import os
from pathlib import Path

from .. import system
from .base import Level, ToolUI

PREVIEW_LINES = 15

# topgrade is interactive (pacnew prompts and the like), so it gets a real
# terminal rather than a captured pipe.
TERMINALS: dict[str, list[str]] = {
    "gnome-terminal": ["--wait", "--"],
    "konsole": ["--hold", "-e"],
    "alacritty": ["-e"],
    "ptyxis": ["--"],
    "kitty": [],
    "xfce4-terminal": ["--hold", "-e"],
    "xterm": ["-hold", "-e"],
}


def _reboot_required() -> bool:
    if system.has("needs-restarting"):
        # Exits non-zero when a reboot is needed.
        return not system.run(["needs-restarting", "-r"]).ok
    return Path("/var/run/reboot-required").exists()


def system_update(ui: ToolUI) -> None:
    ui.section("Update all packages")

    manager = system.package_manager()
    if not manager:
        ui.note("No supported package manager found (apt/dnf/pacman/zypper).", Level.ERROR)
        return

    # Refresh and list are back to back, so they share one elevation prompt.
    steps: list[tuple[str, list[str]]] = []
    if manager.refresh:
        steps.append(("Refreshing package index", [manager.cmd, *manager.refresh]))
    steps.append(("Checking for updates", [manager.cmd, *manager.list_updates]))

    results = ui.run_all(steps, root=True)
    if manager.refresh and not results[0].ok:
        ui.note("Refresh failed. Check your network connection.", Level.ERROR)
        return

    # dnf check-update exits 100 when updates exist and 0 when there are none;
    # pacman -Qu exits 1 on an empty list. Judge by output, not exit code.
    lines = [
        line.strip()
        for line in results[-1].stdout.splitlines()
        if line.strip() and not line.startswith(("Listing", "Last metadata"))
    ]
    if not lines:
        ui.note("Everything is already up to date.", Level.OK)
        return

    ui.section(f"{len(lines)} update(s) available")
    ui.fields([(line.split()[0], " ".join(line.split()[1:])) for line in lines[:PREVIEW_LINES]])
    if len(lines) > PREVIEW_LINES:
        ui.note(f"... and {len(lines) - PREVIEW_LINES} more.")

    if not ui.confirm(f"Install {len(lines)} update(s)?"):
        return

    result = ui.run([manager.cmd, *manager.update], label="Updating packages", root=True)
    if not result.ok:
        return

    # Kernel and glibc updates only take effect after a restart.
    if _reboot_required():
        ui.note("A reboot is required to finish this update.", Level.WARN)


def topgrade(ui: ToolUI) -> None:
    ui.section("Topgrade")

    if not system.has("topgrade"):
        ui.note("topgrade is not installed.", Level.ERROR)
        ui.note(
            "Install it with your package manager: pacman -S topgrade, "
            "or cargo install topgrade elsewhere."
        )
        return

    user = system.desktop_user()
    if not user:
        ui.note("Could not determine the desktop user.", Level.ERROR)
        return

    ui.note(
        "topgrade upgrades packages, flatpak, VS Code extensions, uv tools, "
        "gcloud, helm, firmware and more. It asks its own questions, so it "
        "opens in a terminal window of its own."
    )

    # Reconstruct the session environment so GNOME Shell extensions and
    # session-aware tools work when topgrade is spawned from a root context
    # that did not inherit the graphical session. Each value is a separate
    # argv token for `env`, so a hostile DISPLAY cannot become a command.
    session_env = [
        f"DBUS_SESSION_BUS_ADDRESS={user.dbus}",
        f"WAYLAND_DISPLAY={os.environ.get('WAYLAND_DISPLAY', 'wayland-0')}",
        f"DISPLAY={os.environ.get('DISPLAY', ':0')}",
    ]
    # Fixed literal -- the shell is only here to hold the window open after.
    run_command = [
        "sudo",
        "-u",
        user.name,
        "env",
        *session_env,
        "bash",
        "-c",
        'topgrade; echo; read -r -p "Press Enter to close..."',
    ]

    for terminal, args in TERMINALS.items():
        if not system.has(terminal):
            continue
        ui.run([terminal, *args, *run_command], label=f"Opening topgrade in {terminal}")
        return

    ui.note("No supported terminal emulator found.", Level.ERROR)
    ui.note("Install one of: " + ", ".join(TERMINALS))
