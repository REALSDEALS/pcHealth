"""Restart the audio server.

PipeWire and PulseAudio live in the user's session, not root's, so every call
is dropped to the desktop user with their session bus forwarded.
"""

from __future__ import annotations

import time

from .. import system
from .base import Level, ToolUI

PIPEWIRE_UNITS = ("pipewire", "pipewire-pulse", "wireplumber")


def audio_restart(ui: ToolUI) -> None:
    ui.section("Restart Audio")

    user = system.desktop_user()
    if not user:
        ui.note("Could not determine the desktop user.", Level.ERROR)
        return

    # Exact match: `is-active` answers "inactive" too, which a substring test
    # would happily accept.
    state = system.run_as_user(user, ["systemctl", "--user", "is-active", "pipewire"])

    if state.stdout.strip() == "active":
        ui.note("Detected PipeWire.")
        for unit in PIPEWIRE_UNITS:
            step = ui.step(f"Restarting {unit}")
            result = system.run_as_user(user, ["systemctl", "--user", "restart", unit])
            for line in (result.stdout + result.stderr).splitlines():
                step.output(line)
            step.finish(result.ok, "Done" if result.ok else f"Exit code {result.returncode}")
    elif system.has("pulseaudio"):
        ui.note("Detected PulseAudio.")
        step = ui.step("Restarting PulseAudio")
        # Kill then start as two invocations to avoid a shell compound command.
        system.run_as_user(user, ["pulseaudio", "--kill"])
        time.sleep(0.5)
        result = system.run_as_user(user, ["pulseaudio", "--start"])
        step.finish(result.ok, "Done" if result.ok else f"Exit code {result.returncode}")
    else:
        ui.note("No supported audio server found (PipeWire or PulseAudio).", Level.ERROR)
        return

    ui.note("Audio services restarted.", Level.OK)
