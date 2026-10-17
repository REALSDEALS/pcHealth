"""Hardware information: CPU, GPU, storage (SMART), RAM and temperatures."""

from __future__ import annotations

from pathlib import Path

from .. import probe, smart, system
from .base import Level, ToolUI


def _gb(kib: int) -> str:
    return f"{kib / 1048576:.2f} GB"


def _cpu(ui: ToolUI) -> None:
    ui.section("CPU")
    info = probe.cpu()
    ui.fields(
        [
            ("Name", info.model),
            ("Architecture", info.architecture),
            ("Cores", str(info.cores)),
            ("Threads", str(info.threads)),
            ("Max speed", f"{info.max_mhz} MHz" if info.max_mhz else "N/A"),
            # Sizes come from cpu0, so they are what one core sees.
            *[(f"{level} cache (per core)", size) for level, size in info.caches.items()],
            ("Virtualization", info.virtualization),
        ]
    )


def _gpu(ui: ToolUI) -> None:
    ui.section("GPU")
    found = probe.gpus()
    if found:
        ui.fields([(f"GPU {n}", name) for n, name in enumerate(found, 1)])
    else:
        ui.note("No display adapter found.", Level.WARN)


def _storage(ui: ToolUI) -> None:
    ui.section("Storage")

    if not smart.available():
        disks = probe.block_devices()
        if disks:
            ui.fields([(d.name, f"{d.size_text} {d.kind} {d.model}".strip()) for d in disks])
            ui.note("Install smartmontools for life %, temperature and power-on hours.")
        else:
            ui.note("No physical disks found under /sys/block.", Level.WARN)
        return

    devices = smart.devices()
    if not devices:
        ui.note("smartctl found no devices with usable SMART data.", Level.WARN)
        return

    for device in devices:
        ui.fields(
            [
                ("Model", device.model),
                ("Type", device.media),
                ("Size", f"{device.capacity_gb} GB"),
                ("Temperature", f"{device.temperature_c} C" if device.temperature_c else "N/A"),
                ("Power-on hours", str(device.power_on_hours or "N/A")),
                ("Life left", f"{device.life_left_pct}%" if device.life_left_pct else "N/A"),
                ("Health", device.health_text),
            ]
        )
        if device.passed is False:
            ui.note(f"{device.model} reports SMART failure. Back it up now.", Level.ERROR)


def _memory(ui: ToolUI) -> None:
    ui.section("Memory")
    memory = probe.meminfo()
    total = memory.get("MemTotal", 0)
    if not total:
        ui.note("RAM information not available.", Level.WARN)
        return

    available = memory.get("MemAvailable", 0)
    cache = memory.get("Buffers", 0) + memory.get("Cached", 0) + memory.get("SReclaimable", 0)
    swap_total = memory.get("SwapTotal", 0)

    ui.fields(
        [
            ("Total", _gb(total)),
            ("Used", _gb(total - available)),
            ("Available", _gb(available)),
            ("Buffers / cache", _gb(cache)),
            ("Swap total", _gb(swap_total)),
            ("Swap used", _gb(swap_total - memory.get("SwapFree", 0))),
        ]
    )


def _sensors(ui: ToolUI) -> None:
    """Straight from the kernel's hwmon class.

    The same source lm-sensors reads, so nothing needs to be installed.
    """
    ui.section("Temperatures")
    root = Path("/sys/class/hwmon")
    try:
        chips = sorted(root.iterdir())
    except OSError:
        chips = []

    readings: list[tuple[str, str]] = []
    for chip in chips:
        chip_name = system.read_text(chip / "name") or chip.name
        for entry in sorted(chip.glob("temp*_input")):
            raw = system.read_text(entry)
            if not raw or not raw.lstrip("-").isdigit():
                continue
            label = system.read_text(entry.with_name(entry.name.replace("_input", "_label")))
            # hwmon reports millidegrees Celsius.
            readings.append((f"{chip_name} {label or entry.stem}", f"{int(raw) / 1000:.1f} C"))

    if readings:
        ui.fields(readings)
    else:
        ui.note("No temperature readings exposed by this kernel.")


def hardware_info(ui: ToolUI) -> None:
    _cpu(ui)
    _gpu(ui)
    _storage(ui)
    _memory(ui)
    _sensors(ui)
