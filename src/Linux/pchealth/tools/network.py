"""Ping, traceroute and the network stack reset."""

from __future__ import annotations

from .. import system
from .base import Level, ToolUI

PING_TARGET = "8.8.8.8"
TRACE_TARGET = "google.com"


def ping_short(ui: ToolUI) -> None:
    ui.section(f"Short Ping Test  ({PING_TARGET})")
    # -w caps the total run: without it an unreachable host with a slow DNS
    # path can sit there far longer than four packets suggest.
    result = ui.run(
        ["ping", "-c", "4", "-W", "2", "-w", "15", PING_TARGET],
        label="Sending 4 packets",
        ok="Host is reachable",
        failed="No usable reply",
    )
    if not result.ok:
        ui.note("Check your network connection.", Level.ERROR)


def ping_continuous(ui: ToolUI) -> None:
    ui.section(f"Continuous Ping Test  ({PING_TARGET})")
    step = ui.step("Pinging until stopped")
    code = system.stream(["ping", PING_TARGET], step.output, should_stop=ui.should_stop)
    step.finish(True, f"Stopped (exit {code})")


def traceroute(ui: ToolUI) -> None:
    ui.section(f"Traceroute to {TRACE_TARGET}")
    command = next((c for c in ("traceroute", "tracepath") if system.has(c)), None)
    if not command:
        ui.note("Neither traceroute nor tracepath is installed.", Level.WARN)
        ui.note("Install via: apt install traceroute  (or dnf / pacman / zypper)")
        return

    step = ui.step(f"Tracing with {command}")
    code = system.stream([command, TRACE_TARGET], step.output, should_stop=ui.should_stop)
    step.finish(code == 0, "Route traced" if code == 0 else f"Exit code {code}")


def network_reset(ui: ToolUI) -> None:
    ui.section("Reset Network Stack")
    if not system.has("systemctl"):
        ui.note("systemctl not found. This system may not use systemd.", Level.ERROR)
        return

    ui.note("The network connection will drop briefly.", Level.WARN)
    if not ui.confirm("Restart networking now?"):
        return

    manager_active = system.output(["systemctl", "is-active", "NetworkManager"]) == "active"
    unit = "NetworkManager" if manager_active or system.has("nmcli") else "systemd-networkd"

    steps: list[tuple[str, list[str]]] = [(f"Restarting {unit}", ["systemctl", "restart", unit])]
    if system.has("resolvectl"):
        steps.append(("Flushing DNS cache", ["resolvectl", "flush-caches"]))
    elif system.has("systemd-resolve"):
        steps.append(("Flushing DNS cache", ["systemd-resolve", "--flush-caches"]))

    results = ui.run_all(steps, root=True)
    if all(result.ok for result in results):
        ui.note("Network reset complete.", Level.OK)
    else:
        ui.note("The network stack did not come back cleanly. See the steps above.", Level.ERROR)
