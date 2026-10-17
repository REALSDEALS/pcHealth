# pcHealth for Linux

The Linux half of pcHealth: a terminal menu and a GTK4 desktop app over the
same set of tools. The Windows half lives in `src/Windows` and is PowerShell 7
plus WinUI 3.

## Why Python here

The Windows stack cannot come along: WinUI 3 is Windows-only, and PowerShell 7
is not installed on a Linux machine until someone installs it. That is a poor
first step for a tool you reach for *because* something is broken, so this side
uses what every target distro already ships — Python 3 — and GTK4 with
libadwaita for the desktop app.

The tool list itself is shared: both stacks read `assets/tools.json` in the repo
root, so the menus cannot drift apart.

## Requirements

| | Needs |
|---|---|
| Terminal app | Python 3.11+ — nothing else |
| Desktop app | PyGObject, GTK 4, libadwaita |
| Kernel | 6.0 or newer |

```bash
# Desktop app dependencies, if you want it
sudo dnf install python3-gobject gtk4 libadwaita        # Fedora / RHEL
sudo apt install python3-gi gir1.2-gtk-4.0 gir1.2-adw-1 # Debian / Ubuntu
sudo pacman -S python-gobject gtk4 libadwaita           # Arch / CachyOS
sudo zypper install python3-gobject gtk4 libadwaita     # openSUSE
```

## Running

```bash
# Terminal, straight from the repo -- no install step
python3 -m pchealth

# Desktop app
python3 -m pchealth.gui.app

# Or install the entry points
pip install .          # adds: pchealth, pchealth-gui
pip install '.[gui]'   # also pulls PyGObject from PyPI (needs a compiler)
```

## Privileges

Most tools need root, but neither front-end asks you to run the whole app as
root. Actions elevate one at a time through `pkexec`, falling back to `sudo`
where polkit is absent. Running the terminal app with `sudo` works too and
simply skips the per-action prompt.

The desktop app in particular must **not** be started with sudo: a root process
cannot reach your Wayland session without loosening the display's access
control, and a root-owned toolkit is a bad idea on its own.

## Layout

```
pchealth/
  system.py      process, privilege and platform helpers -- every other
                 module goes through here to touch the system
  smart.py       SMART data, shared by Hardware Information and Health
  health.py      the health report: sections of checks, each with a status
  catalog.py     reads the shared tool catalogue
  tools/         one module per area; a tool is a function over a ToolContext
  cli/           terminal menus and theming
  gui/           GTK4 / libadwaita front-end
```

A tool never talks to the terminal or to GTK, and it never renders a menu of
its own. It emits styled lines and *declares* the choices it needs:

```python
choice = ctx.choose(
    "What should happen?",
    [
        Choice("restart", "Restart", "Restarts the system immediately.", destructive=True),
        Choice("shutdown", "Shut Down", "Powers the system off immediately.", destructive=True),
    ],
)
```

The terminal renders that as a numbered list, the GUI as one button per
option. The moment a tool prints `[1] ... [2] ...` itself, it has decided it
lives in a terminal and the GUI is stuck showing a text box for it.

## Development

```bash
python3 -m ruff check .
python3 -m ruff format --check .
python3 -m mypy pchealth
```

Adding a tool means three things: an entry in `assets/tools.json` with
`"linuxTool"`, a function in `pchealth/tools/`, and a line in the `REGISTRY` in
`pchealth/tools/__init__.py`. CI fails if the catalogue lists a tool the
registry cannot run.
