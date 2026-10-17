"""The main window.

Laid out like the WinUI 3 app on the Windows side: a navigation sidebar, a
Tools page whose entries are grouped cards, and one page per tool with its own
title, description and Run button. Tool output lands in that page rather than
in a single shared console, so switching tools never shows you the previous
tool's text.
"""

from __future__ import annotations

import threading
from collections.abc import Callable

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, GLib, Gtk  # noqa: E402

from .. import catalog, health, system  # noqa: E402
from ..tools import REGISTRY, Cancelled, Level  # noqa: E402
from ..version import get_version  # noqa: E402
from .toolui import GtkToolUI  # noqa: E402

REPO_URL = "https://github.com/REALSDEALS/pcHealth"

# Health statuses map onto libadwaita's own semantic classes, so they follow
# the theme instead of carrying hardcoded colours around.
_STATUS_CLASS = {
    health.Status.GOOD: "success",
    health.Status.WARNING: "warning",
    health.Status.BAD: "error",
    health.Status.UNKNOWN: "dim-label",
    health.Status.INFO: "dim-label",
}
_STATUS_LABEL = {
    health.Status.GOOD: "OK",
    health.Status.WARNING: "Check",
    health.Status.BAD: "Problem",
    health.Status.UNKNOWN: "Unknown",
    health.Status.INFO: "",
}


class ToolPage(Adw.NavigationPage):
    """One tool: its description, a Run button, and its results as rows."""

    def __init__(self, tool: catalog.Tool, window: Gtk.Window) -> None:
        super().__init__(title=tool.name)
        self._tool = tool
        self._window = window
        self._worker: threading.Thread | None = None
        self._stop = threading.Event()

        self._results = Adw.PreferencesPage()
        self._run = Gtk.Button(label="Run", css_classes=["suggested-action"])
        self._stop_button = Gtk.Button(label="Stop", sensitive=False)
        self._run.connect("clicked", self._on_run)
        self._stop_button.connect("clicked", lambda _b: self._stop.set())

        header = Adw.HeaderBar()
        header.pack_end(self._run)
        header.pack_end(self._stop_button)

        self._placeholder = Adw.StatusPage(
            title=tool.name,
            description=tool.note or f"{tool.category} tool. Press Run to start.",
            icon_name="media-playback-start-symbolic",
        )
        self._body = Gtk.Stack()
        self._body.add_named(self._placeholder, "idle")
        self._body.add_named(self._results, "results")

        view = Adw.ToolbarView()
        view.add_top_bar(header)
        view.set_content(self._body)
        self.set_child(view)

    def _on_run(self, _button: Gtk.Button) -> None:
        if self._worker and self._worker.is_alive():
            return
        implementation = REGISTRY.get(self._tool.id)
        if implementation is None:
            return

        # A fresh page per run: results from the previous run must not linger.
        self._body.remove(self._results)
        self._results = Adw.PreferencesPage()
        self._body.add_named(self._results, "results")
        self._body.set_visible_child_name("results")

        self._stop.clear()
        self._run.set_sensitive(False)
        self._stop_button.set_sensitive(True)

        ui = GtkToolUI(self._results, self._window, self._stop)

        def work() -> None:
            try:
                implementation(ui)
            except Cancelled:
                ui.note("Cancelled.", Level.INFO)
            except OSError as exc:
                ui.note(f"Tool error: {exc}", Level.ERROR)
            finally:
                GLib.idle_add(self._finish)

        self._worker = threading.Thread(target=work, daemon=True, name=f"pchealth-{self._tool.id}")
        self._worker.start()

    def _finish(self) -> bool:
        self._stop_button.set_sensitive(False)
        self._run.set_sensitive(True)
        return GLib.SOURCE_REMOVE


def _tools_page(open_tool: Callable[[catalog.Tool], None]) -> Adw.NavigationPage:
    """The tool list, grouped by category the way the WinUI 3 page groups it."""
    page = Adw.PreferencesPage()

    # Group properly rather than starting a new heading on every change: the
    # catalogue is in menu order, so categories interleave and a naive scan
    # prints "Updates" three times.
    by_category: dict[str, list[catalog.Tool]] = {}
    for tool in catalog.active():
        by_category.setdefault(tool.category, []).append(tool)

    for category, tools in by_category.items():
        group = Adw.PreferencesGroup(title=category)
        for tool in tools:
            row = Adw.ActionRow(title=tool.name, subtitle=tool.note, activatable=True)
            row.add_suffix(Gtk.Image.new_from_icon_name("go-next-symbolic"))
            row.connect("activated", lambda _row, t=tool: open_tool(t))
            group.add(row)
        page.add(group)

    return Adw.NavigationPage(title="Tools", child=page)


def _health_page() -> Adw.NavigationPage:
    """The same report the terminal prints, as rows with a status icon."""
    page = Adw.PreferencesPage()
    sections = health.collect()

    summary = health.overall(sections)
    banner = Adw.PreferencesGroup(title="Overall")
    banner.add(
        Adw.ActionRow(
            title=summary.value.capitalize(),
            subtitle=f"{len(sections)} areas checked",
            css_classes=[_STATUS_CLASS[summary]],
        )
    )
    page.add(banner)

    for section in sections:
        group = Adw.PreferencesGroup(title=section.title)
        for check in section.checks:
            row = Adw.ActionRow(title=check.label, subtitle=check.value)
            if check.detail:
                row.set_tooltip_text(check.detail)
            label = _STATUS_LABEL[check.status]
            if label:
                row.add_suffix(
                    Gtk.Label(label=label, css_classes=["caption", _STATUS_CLASS[check.status]])
                )
            group.add(row)
        page.add(group)

    return Adw.NavigationPage(title="Health", child=page)


def _about_page() -> Adw.NavigationPage:
    status = Adw.StatusPage(
        icon_name="help-about-symbolic",
        title="pcHealth",
        description=(
            f"Version {get_version()}\n\n"
            "Check the health of your Linux installation, drivers, updates and battery.\n"
            "Made by REALSDEALS — licensed under GNU GPL-3."
        ),
    )
    link = Gtk.Button(label="Open the repository", halign=Gtk.Align.CENTER, css_classes=["pill"])
    link.connect("clicked", lambda _b: system.open_url(REPO_URL))
    status.set_child(link)
    return Adw.NavigationPage(title="About", child=status)


class MainWindow(Adw.ApplicationWindow):
    def __init__(self, application: Adw.Application) -> None:
        super().__init__(
            application=application,
            title="pcHealth",
            default_width=1100,
            default_height=720,
        )

        self._content = Adw.NavigationView()
        self._pages = {
            "health": _health_page,
            "tools": lambda: _tools_page(self._open_tool),
            "about": _about_page,
        }

        sidebar = Gtk.ListBox(
            css_classes=["navigation-sidebar"],
            selection_mode=Gtk.SelectionMode.SINGLE,
        )
        for key, label, icon in (
            ("health", "Health", "utilities-system-monitor-symbolic"),
            ("tools", "Tools", "applications-utilities-symbolic"),
            ("about", "About", "help-about-symbolic"),
        ):
            row = Adw.ActionRow(title=label)
            row.add_prefix(Gtk.Image.new_from_icon_name(icon))
            row.page_key = key
            sidebar.append(row)
        sidebar.connect("row-selected", self._on_nav)

        sidebar_view = Adw.ToolbarView()
        sidebar_view.add_top_bar(
            Adw.HeaderBar(
                title_widget=Adw.WindowTitle(title="pcHealth", subtitle=f"v{get_version()}"),
                show_end_title_buttons=False,
            )
        )
        sidebar_view.set_content(Gtk.ScrolledWindow(child=sidebar, vexpand=True))
        # Said once, at the bottom, rather than crowding the window controls.
        if not system.is_root():
            sidebar_view.add_bottom_bar(
                Gtk.Label(
                    label="Each action asks for elevation",
                    css_classes=["dim-label", "caption"],
                    margin_top=8,
                    margin_bottom=8,
                )
            )

        self.set_content(
            Adw.NavigationSplitView(
                sidebar=Adw.NavigationPage(title="pcHealth", child=sidebar_view),
                content=Adw.NavigationPage(title="pcHealth", child=self._content),
                min_sidebar_width=240,
            )
        )

        sidebar.select_row(sidebar.get_row_at_index(0))

    def _on_nav(self, _list: Gtk.ListBox, row: Gtk.ListBoxRow | None) -> None:
        key = getattr(row, "page_key", None)
        if key is None:
            return
        self._content.replace([self._pages[key]()])

    def _open_tool(self, tool: catalog.Tool) -> None:
        self._content.push(ToolPage(tool, self))
