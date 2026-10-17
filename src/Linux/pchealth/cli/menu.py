"""The terminal menus."""

from __future__ import annotations

from .. import catalog, health, system
from ..tools import REGISTRY, Cancelled
from ..version import get_version
from . import programs, theme, ui

REPO_URL = "https://github.com/REALSDEALS/pcHealth"
RELEASES_URL = f"{REPO_URL}/releases"


def _run_tool(tool: catalog.Tool) -> None:
    # The tool prints its own heading, so the menu only clears the screen --
    # printing the name here as well would show it twice.
    theme.clear()
    theme.write("  pcHealth", "muted")
    theme.write()
    implementation = REGISTRY.get(tool.id)
    if implementation is None:
        theme.write(f"No implementation registered for '{tool.id}'.", "error")
        return
    try:
        implementation(ui.TerminalUI())
    except Cancelled:
        theme.write()
        theme.write("Cancelled.", "muted")
    except KeyboardInterrupt:
        theme.write()
        theme.write("Stopped.", "muted")
    except OSError as exc:
        theme.write()
        theme.write(f"[!!] Tool error: {exc}", "error")


_STATUS_STYLE = {
    health.Status.GOOD: "ok",
    health.Status.WARNING: "warn",
    health.Status.BAD: "error",
    health.Status.UNKNOWN: "muted",
    health.Status.INFO: "info",
}


def _health_screen() -> str:
    theme.header("Health", "Reading system state...")

    sections = health.collect()
    overall = health.overall(sections)
    theme.write(f"  Overall: {overall.value.upper()}", _STATUS_STYLE[overall])

    for section in sections:
        theme.write()
        theme.write(f"  {section.title}", "head")
        width = max((len(check.label) for check in section.checks), default=0)
        for check in section.checks:
            row = f"    {check.label.ljust(width)}   {check.value}"
            theme.write(row, _STATUS_STYLE[check.status])
            if check.detail:
                theme.write(f"    {' ' * width}   {check.detail}", "muted")

    theme.write()
    nav = input("  [1] Back to Main Menu  [2] Exit: ").strip()
    return "exit" if nav == "2" else "main"


def _tools_menu() -> str:
    tools = catalog.active()

    while True:
        theme.header("Tools")
        for index, tool in enumerate(tools, start=1):
            theme.option(str(index), tool.name, tool.note)

        theme.write()
        nav_programs = len(tools) + 1
        nav_main = len(tools) + 2
        nav_exit = len(tools) + 3
        theme.option(str(nav_programs), "Programs Menu")
        theme.option(str(nav_main), "Back to Main Menu")
        theme.option(str(nav_exit), "Exit")
        theme.write()

        choice = input("  Choice: ").strip()
        if not choice.isdigit():
            theme.write("Invalid choice.", "error")
            continue

        number = int(choice)
        if number == nav_programs:
            return "programs"
        if number == nav_main:
            return "main"
        if number == nav_exit:
            return "exit"
        if 1 <= number <= len(tools):
            _run_tool(tools[number - 1])
            theme.write()
            nav = input("  [1] Back to Tools  [2] Main Menu  [3] Exit: ").strip()
            if nav == "2":
                return "main"
            if nav == "3":
                return "exit"
            continue

        theme.write("Invalid choice.", "error")


def _main_menu() -> str:
    theme.header("Main Menu", f"Linux  --  v{get_version()}")

    theme.write("  Thanks for downloading and using pcHealth!")
    theme.write("  Made by REALSDEALS - Licensed under GNU-3", "muted")
    theme.write()

    if not system.is_root():
        theme.write("  Not running as root -- each action will ask for elevation.", "warn")
        theme.write("  Run `sudo pchealth` to be asked once instead.", "muted")
        theme.write()

    theme.option("1", "Health")
    theme.option("2", "Tools")
    theme.option("3", "Programs")
    theme.write()
    theme.option("4", "Go to repository")
    theme.option("5", "Check for pre-releases")
    theme.write()
    theme.option("6", "Exit")
    theme.write()

    choice = input("  Choice: ").strip()
    if choice == "1":
        return "health"
    if choice == "2":
        return "tools"
    if choice == "3":
        return "programs"
    if choice == "4":
        system.open_url(REPO_URL)
        return "main"
    if choice == "5":
        system.open_url(RELEASES_URL)
        return "main"
    if choice == "6":
        return "exit"

    theme.write("Invalid choice.", "error")
    return "main"


def run() -> int:
    target = "main"
    while True:
        try:
            if target == "health":
                target = _health_screen()
            elif target == "tools":
                target = _tools_menu()
            elif target == "programs":
                target = programs.show()
            elif target == "exit":
                theme.write()
                theme.write("  Goodbye.", "muted")
                return 0
            else:
                target = _main_menu()
        except (KeyboardInterrupt, EOFError):
            theme.write()
            theme.write("  Goodbye.", "muted")
            return 0
