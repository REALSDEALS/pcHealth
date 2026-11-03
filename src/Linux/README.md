# pcHealth for Linux

A terminal menu and a GTK 4 desktop app that run the same set of tools. The
Windows version is in `src/Windows`.

This part is written in Python because every supported distro already ships
Python 3; PowerShell 7 and WinUI 3 are not available out of the box on Linux.

## Requirements

| Part         | Needs                                  |
|--------------|----------------------------------------|
| Terminal app | Python 3.11 or newer                   |
| Desktop app  | Python 3.11+, PyGObject, GTK 4, libadwaita |

```bash
sudo dnf install python3-gobject gtk4 libadwaita         # Fedora / RHEL
sudo apt install python3-gi gir1.2-gtk-4.0 gir1.2-adw-1  # Debian / Ubuntu
sudo pacman -S python-gobject gtk4 libadwaita            # Arch
sudo zypper install python3-gobject gtk4 libadwaita      # openSUSE
```

Some tools use optional programs when they are installed: `smartctl`
(disk health), `fwupdmgr` (firmware), `traceroute`, `topgrade`.

## Running

```bash
cd src/Linux
python3 -m pchealth          # terminal menu
python3 -m pchealth --version
python3 -m pchealth.gui.app  # desktop app

pip install .                # optional: installs the pchealth and pchealth-gui commands
```

## Root access

Run both apps as your normal user. A tool that needs root asks for the
password once per tool run, through `pkexec`, or `sudo` when polkit is not
installed. Running the terminal app with `sudo` also works and skips the
prompt.

Do not start the desktop app with `sudo`: a root process cannot open a window
on a Wayland session.

How it works: `system.run_root_batch` starts `privileged.py` through `pkexec`
and sends it a list of commands as JSON on stdin. The helper runs each
command (no shell) and streams the output back. It exits when the list is
done.

Note: when pcHealth runs from a folder the user can write to (a git clone, a
venv), `privileged.py` itself is user-writable. Anything running as that user
could change it before the next password prompt. Treat a clone like any other
script you run with root rights.

## Code layout

```text
pchealth/
  __main__.py    terminal entry point: python3 -m pchealth
  system.py      running commands, elevation, distro and package-manager detection
  privileged.py  the helper that pkexec runs as root (standard library only)
  probe.py       CPU, memory, mounts, GPU and Secure Boot read from /proc and /sys
  smart.py       disk health from smartctl's JSON output
  health.py      the health report: sections of checks with a status each
  catalog.py     reads assets/tools.json
  tools/         the tools, one module per area; REGISTRY in __init__.py
  cli/           terminal menus and colours
  gui/           GTK 4 / libadwaita app
```

### How a tool works

A tool is a function that takes a `ToolUI` (`tools/base.py`). It never prints
and never builds widgets itself. It describes its results, and each front-end
renders them: the terminal as text, the GTK app as rows and expanders.

```python
def example(ui: ToolUI) -> None:
    ui.section("Disks")
    ui.fields([("Model", "Samsung 980"), ("Health", "OK")])
    if ui.confirm("Trim all SSDs now?"):
        ui.run(["fstrim", "-av"], label="Trimming", root=True)
```

`ui.choose()` offers a list of options (`Choice`), shown as numbers in the
terminal and as buttons in the GUI. `ui.run()` and `ui.run_all()` run commands,
show their output and exit code, and ask for root once for a whole batch.

The GTK app runs each tool on a worker thread; `gui/toolui.py` passes every
widget change to the main loop with `GLib.idle_add`.

## Adding a tool

1. Add an entry to `assets/tools.json` with `"linux"` in `platforms` and a
   `"linuxTool"` id. Set `"needsMutableOS": true` if it changes packages or
   boot files, so it is hidden on image-based systems.
2. Write the function in a module under `pchealth/tools/`.
3. Add it to `REGISTRY` in `pchealth/tools/__init__.py`.

CI fails when `tools.json` lists a Linux tool that is not in `REGISTRY`.

## Checks

Run these from `src/Linux` before committing; CI runs the same three:

```bash
python3 -m ruff check .
python3 -m ruff format --check .
python3 -m mypy pchealth
```
