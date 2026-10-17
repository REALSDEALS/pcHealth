"""Recent error and warning entries from the systemd journal."""

from __future__ import annotations

from .. import system
from .base import Choice, Level, ToolUI

_VIEWS: dict[str, tuple[Choice, list[str]]] = {
    "today": (
        Choice("today", "Errors from today", "Priority err and above, since midnight"),
        ["journalctl", "--priority=err", "--since=today", "--no-pager"],
    ),
    "recent": (
        Choice("recent", "Last 100 warnings and errors", "Priority warning and above"),
        ["journalctl", "--priority=warning", "-n", "100", "--no-pager"],
    ),
    "boot": (
        Choice("boot", "Boot messages", "This boot, last 100 lines"),
        ["journalctl", "-b", "--no-pager", "-n", "100"],
    ),
    "kernel": (
        Choice("kernel", "Kernel messages", "dmesg, errors and warnings"),
        ["dmesg", "--level=err,warn"],
    ),
    "failed": (
        Choice("failed", "Failed services", "systemd units that did not start"),
        ["systemctl", "--failed", "--no-legend", "--no-pager"],
    ),
}


def system_logs(ui: ToolUI) -> None:
    ui.section("System Logs")

    if not system.has("journalctl"):
        ui.note("journalctl not found. This system may not use systemd.", Level.ERROR)
        return

    choice = ui.choose("Which log?", [view[0] for view in _VIEWS.values()])
    if choice is None:
        return

    label, argv = _VIEWS[choice]
    if choice == "failed":
        failed = system.output(argv) or ""
        units = [line for line in failed.splitlines() if line.strip()]
        if not units:
            ui.note("No failed units.", Level.OK)
            return
        ui.fields([(unit.split()[0], " ".join(unit.split()[1:])) for unit in units])
        ui.note("Inspect one with: journalctl -u <unit> -b")
        return

    # The journal is root-readable only for system messages; a plain user sees
    # their own entries and nothing else, which silently looks like a clean log.
    ui.run(argv, label=label.label, root=True, ok="Read")
