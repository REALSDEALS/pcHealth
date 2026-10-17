"""Version lookup.

The repo-root VERSION file is the single source of truth, the same one the
WinUI project bakes into its assembly and the one hatch stamps into the wheel
at build time. An installed copy has no repo around it, so it falls back to
that stamped metadata; the constant below only survives a broken install.
"""

from importlib import metadata
from pathlib import Path

__version__ = "0.0.0"


def _from_repo() -> str | None:
    # pchealth/version.py -> pchealth -> Linux -> src -> repo root
    candidate = Path(__file__).resolve().parents[3] / "VERSION"
    try:
        text = candidate.read_text(encoding="utf-8").strip()
    except OSError:
        return None
    return text or None


def get_version() -> str:
    repo = _from_repo()
    if repo:
        return repo
    try:
        return metadata.version("pchealth")
    except metadata.PackageNotFoundError:
        return __version__
