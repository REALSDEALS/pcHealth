"""Battery report, straight from the kernel's power_supply class.

No external tool needed: upower and acpi both read these same sysfs files.
"""

from __future__ import annotations

from pathlib import Path

from .. import system
from .base import Level, ToolUI

SUPPLY_ROOT = Path("/sys/class/power_supply")


def _attribute(directory: Path, *names: str) -> str | None:
    """Read the first attribute that exists.

    Names vary by driver -- energy_* on one laptop, charge_* on the next -- and
    any of them may be absent entirely.
    """
    for name in names:
        value = system.read_text(directory / name)
        if value:
            return value
    return None


def _micro(raw: str | None) -> str:
    """sysfs reports micro-units throughout."""
    try:
        return f"{int(raw) / 1e6:.2f}" if raw else "N/A"
    except ValueError:
        return "N/A"


def _health(full: str | None, design: str | None) -> float | None:
    """Drivers report either energy (uWh) or charge (uAh).

    The ratio holds for both, as long as full and design come from the pair.
    """
    try:
        if full and design and float(design) > 0:
            return round(float(full) / float(design) * 100, 1)
    except ValueError:
        pass
    return None


def battery_report(ui: ToolUI) -> None:
    if not SUPPLY_ROOT.exists():
        ui.note(f"{SUPPLY_ROOT} not found -- this kernel exposes no power supplies.", Level.ERROR)
        return

    try:
        batteries = [d for d in sorted(SUPPLY_ROOT.iterdir()) if _attribute(d, "type") == "Battery"]
    except OSError as exc:
        ui.note(f"Could not read {SUPPLY_ROOT}: {exc}", Level.ERROR)
        return

    if not batteries:
        ui.note("No battery detected -- this looks like a desktop system.", Level.WARN)
        return

    for battery in batteries:
        ui.section(f"Battery {battery.name}")

        full = _attribute(battery, "energy_full", "charge_full")
        design = _attribute(battery, "energy_full_design", "charge_full_design")
        unit = "Wh" if (battery / "energy_full").exists() else "Ah"
        health = _health(full, design)
        power = _attribute(battery, "power_now", "current_now")
        capacity = _attribute(battery, "capacity")
        cycles = _attribute(battery, "cycle_count")

        ui.fields(
            [
                ("Manufacturer", _attribute(battery, "manufacturer") or "N/A"),
                ("Model", _attribute(battery, "model_name") or "N/A"),
                ("Technology", _attribute(battery, "technology") or "N/A"),
                ("Status", _attribute(battery, "status") or "N/A"),
                ("Charge", f"{capacity}%" if capacity else "N/A"),
                (f"Full ({unit})", _micro(full)),
                (f"Design ({unit})", _micro(design)),
                (f"Now ({unit})", _micro(_attribute(battery, "energy_now", "charge_now"))),
                ("Voltage (V)", _micro(_attribute(battery, "voltage_now"))),
                ("Draw", f"{_micro(power)} {'W' if unit == 'Wh' else 'A'}" if power else "N/A"),
                ("Cycle count", cycles or "Not reported by driver"),
                ("Health", f"{health}% of design capacity" if health is not None else "N/A"),
            ]
        )

        if health is not None:
            verdict, level = (
                ("The battery holds most of its design capacity.", Level.OK)
                if health >= 80
                else ("Worn -- noticeably reduced runtime.", Level.WARN)
                if health >= 60
                else ("Poor -- consider replacing the battery.", Level.ERROR)
            )
            ui.note(verdict, level)
        if not cycles:
            ui.note("Many laptop batteries do not expose a cycle count to the kernel.")
