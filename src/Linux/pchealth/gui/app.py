"""GTK4 / libadwaita front-end.

The window runs unprivileged on purpose. A root-owned GUI cannot reach the
user's Wayland session without loosening the display's own access control, and
a toolkit running as root is a bad idea regardless. Privilege is raised per
action through pkexec instead -- see system.elevated().
"""

from __future__ import annotations

import sys

APP_ID = "nl.realsdeals.pcHealth"

_MISSING_GTK = """pcHealth GUI needs PyGObject with GTK 4 and libadwaita.

Install it with your package manager:
  Fedora / RHEL:     dnf install python3-gobject gtk4 libadwaita
  Debian / Ubuntu:   apt install python3-gi gir1.2-gtk-4.0 gir1.2-adw-1
  Arch / CachyOS:    pacman -S python-gobject gtk4 libadwaita
  openSUSE:          zypper install python3-gobject gtk4 libadwaita

The terminal version needs none of this -- run: python3 -m pchealth
"""

# On Silverblue, Bazzite, Kinoite and MicroOS the package manager above cannot
# install into /usr at all, so pointing at it would just waste the user's time.
_MISSING_GTK_IMAGE_BASED = """pcHealth GUI needs PyGObject with GTK 4 and libadwaita.

This is an image-based system, so /usr is read-only and a normal package
install will not work. Either layer it onto the image:

  rpm-ostree install python3-gobject
  systemctl reboot

or run pcHealth inside a toolbox, where installing is ordinary again:

  toolbox enter
  sudo dnf install python3-gobject gtk4 libadwaita

The terminal version needs none of this -- run: python3 -m pchealth
"""


def main() -> int:
    if sys.platform != "linux":
        print("pcHealth GUI runs on Linux only.", file=sys.stderr)
        return 1

    try:
        import gi

        gi.require_version("Gtk", "4.0")
        gi.require_version("Adw", "1")
        from gi.repository import Adw
    except (ImportError, ValueError):
        from .. import system

        hint = _MISSING_GTK_IMAGE_BASED if system.is_image_based() else _MISSING_GTK
        print(hint, file=sys.stderr)
        return 1

    from .window import MainWindow

    class PcHealthApplication(Adw.Application):
        def __init__(self) -> None:
            super().__init__(application_id=APP_ID)

        def do_activate(self) -> None:
            window = self.props.active_window or MainWindow(self)
            window.present()

    return PcHealthApplication().run(sys.argv)


def _run_as_script() -> int:
    """Entry point for `python app.py`, which has no package context.

    Relative imports fail when this file is run as a plain script rather than
    through the package, so put src/Linux on the path and re-enter the module
    the normal way. People do reach for the file they are looking at; that
    should work, not produce an ImportError.

    This only works here because the gi and window imports live inside main().
    A module whose imports run at import time -- __main__.py, for one -- fails
    before any guard like this can help, so it has none.
    """
    import pathlib
    import sys

    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]))
    from pchealth.gui.app import main as packaged_main

    return packaged_main()


if __name__ == "__main__":
    raise SystemExit(main() if __package__ else _run_as_script())
