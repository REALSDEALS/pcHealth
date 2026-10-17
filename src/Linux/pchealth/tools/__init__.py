"""Tool registry: catalogue id -> implementation."""

from __future__ import annotations

from . import (
    audio,
    battery,
    boot,
    cleanup,
    firmware,
    hardware,
    logs,
    network,
    power,
    sysinfo,
    updates,
)
from .base import Cancelled, Choice, Level, ToolFunc, ToolUI

REGISTRY: dict[str, ToolFunc] = {
    "system-info": sysinfo.system_info,
    "hardware-info": hardware.hardware_info,
    "ping-short": network.ping_short,
    "ping-continuous": network.ping_continuous,
    "traceroute": network.traceroute,
    "network-reset": network.network_reset,
    "bios-password": sysinfo.bios_password,
    "power-options": power.power_options,
    "system-update": updates.system_update,
    "topgrade": updates.topgrade,
    "battery-report": battery.battery_report,
    "scan-repair": cleanup.scan_repair,
    "disk-optimize": cleanup.disk_optimize,
    "firmware-update": firmware.firmware_update,
    "boot-repair": boot.boot_repair,
    "disk-cleanup": cleanup.disk_cleanup,
    "audio-restart": audio.audio_restart,
    "system-logs": logs.system_logs,
}

__all__ = ["REGISTRY", "Cancelled", "Choice", "Level", "ToolFunc", "ToolUI"]
