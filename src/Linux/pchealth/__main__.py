"""Entry point for the Linux CLI.

Mirrors what src/Windows/CLI/Start.ps1 does on the Windows side: check the
platform floor, say something useful when it is not met, then hand over to the
menu. There is no dependency bootstrap to do -- Python 3 is already installed
on every distro pcHealth targets, which is the reason this side is Python.
"""

from __future__ import annotations

import sys

from . import system
from .cli import menu, theme
from .version import get_version

MINIMUM_KERNEL_MAJOR = 6


def main() -> int:
    if sys.platform != "linux":
        print("pcHealth for Linux runs on Linux only.", file=sys.stderr)
        print("On Windows, use src/Windows/CLI/Start.ps1.", file=sys.stderr)
        return 1

    major = system.kernel_major()
    if major is None:
        theme.write(f"Could not parse the kernel version ({system.kernel_release()}).", "error")
        return 1
    if major < MINIMUM_KERNEL_MAJOR:
        theme.write(f"pcHealth cannot run on kernel {system.kernel_release()}.", "error")
        theme.write(f"Minimum required: kernel {MINIMUM_KERNEL_MAJOR}.0.", "error")
        theme.write("https://www.kernel.org/", "muted")
        return 1

    if "--version" in sys.argv[1:]:
        print(f"pcHealth {get_version()}")
        return 0

    try:
        return menu.run()
    except BrokenPipeError:
        # `pchealth | head` closes the pipe early. That is not an error, but
        # Python would otherwise print a traceback on the way out.
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
