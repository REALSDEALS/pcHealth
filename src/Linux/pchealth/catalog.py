"""The shared tool catalogue.

Reads assets/tools.json from the repo root -- the same file the PowerShell
menus read -- so the tool list cannot drift between the two stacks. An
installed copy ships its own catalogue next to the package.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from . import system


@dataclass(frozen=True)
class Tool:
    id: str
    name: str
    category: str
    note: str = ""
    needs_mutable_os: bool = False

    @property
    def label(self) -> str:
        return f"{self.name}  ({self.note})" if self.note else self.name


def _catalogue_path() -> Path:
    packaged = Path(__file__).resolve().parent / "tools.json"
    if packaged.exists():
        return packaged
    # pchealth -> Linux -> src -> repo root
    return Path(__file__).resolve().parents[3] / "assets" / "tools.json"


@lru_cache(maxsize=1)
def load() -> list[Tool]:
    """Every Linux tool in the catalogue, in menu order.

    A malformed catalogue is a packaging bug, not a user error, so it raises
    rather than silently presenting an empty menu.
    """
    raw = json.loads(_catalogue_path().read_text(encoding="utf-8"))
    tools = []
    for entry in raw["tools"]:
        if "linux" not in entry.get("platforms", []):
            continue
        tools.append(
            Tool(
                id=entry["linuxTool"],
                name=entry["name"],
                category=entry.get("category", "Other"),
                note=entry.get("note", ""),
                needs_mutable_os=entry.get("needsMutableOS", False),
            )
        )
    return tools


def active() -> list[Tool]:
    """The tools that make sense on this machine right now."""
    image_based = system.is_image_based()
    return [tool for tool in load() if not (tool.needs_mutable_os and image_based)]
