"""Terminal styling.

ANSI only -- no curses, no third-party dependency. The Linux app has to run on
a machine that is already having a bad day, so it asks nothing of the system
beyond a terminal that understands colour, and drops the colour when it does
not (a pipe, a log file, NO_COLOR).
"""

from __future__ import annotations

import os
import shutil
import sys

RESET = "\033[0m"

_CODES = {
    "head": "\033[1;36m",
    "info": "",
    "ok": "\033[32m",
    "warn": "\033[33m",
    "error": "\033[31m",
    "muted": "\033[90m",
    "accent": "\033[36m",
}


def colour_enabled() -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    if os.environ.get("TERM") == "dumb":
        return False
    return sys.stdout.isatty()


def paint(text: str, style: str) -> str:
    if not colour_enabled():
        return text
    code = _CODES.get(style, "")
    return f"{code}{text}{RESET}" if code else text


def write(text: str = "", style: str = "info") -> None:
    print(paint(text, style))


def width(default: int = 80) -> int:
    return shutil.get_terminal_size((default, 24)).columns


def clear() -> None:
    if colour_enabled():
        # Home the cursor and clear, rather than shelling out to `clear`.
        print("\033[H\033[2J", end="")


def rule(char: str = "=") -> None:
    write(char * min(width(), 70), "muted")


def header(title: str, subtitle: str = "") -> None:
    clear()
    rule()
    write(f"  pcHealth  --  {title}", "head")
    if subtitle:
        write(f"  {subtitle}", "muted")
    rule()
    write()


def option(key: str, label: str, note: str = "") -> None:
    line = f"  [{key}]".ljust(7) + label
    if note:
        line += paint(f"  ({note})", "muted") if colour_enabled() else f"  ({note})"
    print(line)
