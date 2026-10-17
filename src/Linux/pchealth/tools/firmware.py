"""Firmware updates through fwupd / LVFS.

The vendor-neutral counterpart to HP Image Assistant on Windows: fwupd ships
BIOS, dock, SSD and peripheral firmware for most vendors.
"""

from __future__ import annotations

from .. import system
from .base import Level, ToolUI

# fwupd is a daemon; its CLI still exits having printed nothing useful when it
# is masked or not running. An empty update list must never become an
# invitation to flash firmware.
_DAEMON_DOWN = ("Failed to connect to daemon", "Failed to load daemon", "could not be activated")
_REFRESH_FAILED = ("Failed to download", "transient failure", "Failed to connect")
_NO_UPDATES = (
    "No updatable devices",
    "No updates available",
    "Devices with no available firmware updates",
)


def firmware_update(ui: ToolUI) -> None:
    ui.section("Firmware Update")

    if not system.has("fwupdmgr"):
        ui.note("fwupdmgr is not installed.", Level.ERROR)
        ui.note("Install fwupd with your package manager: apt, dnf, pacman or zypper.")
        return

    # --force refreshes even when the cached metadata is still considered
    # fresh. Both queries run under one elevation prompt.
    refresh, updates = ui.run_all(
        [
            ("Refreshing metadata from LVFS", ["fwupdmgr", "refresh", "--force"]),
            ("Checking for firmware updates", ["fwupdmgr", "get-updates"]),
        ],
        root=True,
    )

    if any(marker in updates.stdout for marker in _DAEMON_DOWN):
        ui.note("Could not reach the fwupd daemon.", Level.ERROR)
        ui.note("Start it with: systemctl start fwupd")
        return

    # fwupdmgr exits non-zero when there is simply nothing to do, so read text.
    if not updates.stdout.strip() or any(marker in updates.stdout for marker in _NO_UPDATES):
        # Without fresh metadata the verdict reflects whatever was cached,
        # which may be months old -- say so rather than reporting "up to date".
        if any(marker in refresh.stdout for marker in _REFRESH_FAILED):
            ui.note("No updates found, but the LVFS metadata could not be refreshed.", Level.WARN)
            ui.note("This answer is based on cached data -- check again once you are online.")
        else:
            ui.note("All firmware is up to date.", Level.OK)
        return

    ui.section("Updates available")
    ui.fields(
        [(line.split(":")[0].strip(), line) for line in updates.stdout.splitlines() if line.strip()]
    )
    ui.note(
        "Firmware updates carry real risk. Do not power the machine off while "
        "one is running, and plug in the charger on a laptop.",
        Level.WARN,
    )

    if not ui.confirm("Install these firmware updates?"):
        return

    result = ui.run(["fwupdmgr", "update"], label="Installing firmware", root=True)
    if result.ok:
        ui.note("Some devices only apply the update on the next reboot.", Level.OK)
