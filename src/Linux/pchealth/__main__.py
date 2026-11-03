"""Entry point for the Linux CLI.

Checks that it is running on Linux, then hands over to the menu. There is no
dependency bootstrap to do -- Python 3 is already installed on every distro
pcHealth targets, which is the reason this side is Python.
"""

from __future__ import annotations

import sys

from .cli import menu
from .version import get_version


def main() -> int:
    if sys.platform != "linux":
        print("pcHealth for Linux runs on Linux only.", file=sys.stderr)
        print("On Windows, use src/Windows/CLI/Start.ps1.", file=sys.stderr)
        return 1

    # No kernel minimum: nothing here needs a recent kernel, and a floor of
    # 6.0 shut out RHEL/Rocky/Alma 9, Debian 11 and Ubuntu 22.04.
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
