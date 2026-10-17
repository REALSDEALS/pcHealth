"""Shutdown, reboot and log off."""

from __future__ import annotations

from .. import system
from .base import Choice, Level, ToolUI


def power_options(ui: ToolUI) -> None:
    ui.section("Power Options")

    choice = ui.choose(
        "What should happen?",
        [
            Choice("logoff", "Log Off", "Ends the desktop session.", destructive=True),
            Choice("restart", "Restart", "Restarts the system immediately.", destructive=True),
            Choice("shutdown", "Shut Down", "Powers the system off immediately.", destructive=True),
        ],
    )
    if choice is None:
        return

    if choice == "logoff":
        # Under sudo the environment describes root; log off the human instead.
        user = system.desktop_user()
        if not user:
            ui.note("Could not determine the desktop user.", Level.ERROR)
            return
        if ui.confirm(f"Log off {user.name}?"):
            # loginctl ends the session cleanly, unlike killing the processes.
            ui.run(["loginctl", "terminate-user", user.name], label="Ending session", root=True)
        return

    label, argv = {
        "restart": ("Restarting", ["shutdown", "-r", "now"]),
        "shutdown": ("Shutting down", ["shutdown", "-h", "now"]),
    }[choice]
    if ui.confirm(f"{label.rstrip('ing')}? This closes everything immediately."):
        ui.run(argv, label=label, root=True)
