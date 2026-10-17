"""The GTK rendering of a tool.

The terminal turns these calls into text; here they become widgets. A section
is a group, fields are rows, a note is a styled row, and a step is an expander
whose raw command output stays folded away -- because if you wanted to read a
console you would have run the terminal version.

Tools run on a worker thread and GTK may only be touched from the main loop,
so every method below schedules its work with GLib.idle_add. Those callbacks
run in the order they were queued, which is what lets a step's output arrive
after the step's row has been built.
"""

from __future__ import annotations

import threading
from collections.abc import Callable, Sequence

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, GLib, Gtk, Pango  # noqa: E402

from ..tools.base import Choice, Level, Step, ToolUI  # noqa: E402
from . import dialogs  # noqa: E402

_NOTE_CLASS = {
    Level.INFO: "dim-label",
    Level.OK: "success",
    Level.WARN: "warning",
    Level.ERROR: "error",
}


def _wrapping_row(title: str, subtitle: str = "", css: str = "") -> Adw.ActionRow:
    row = Adw.ActionRow(title=title, subtitle=subtitle)
    # Long values -- a model name, a command line, a log line -- must wrap
    # rather than run off the edge of the window.
    row.set_title_lines(0)
    row.set_subtitle_lines(0)
    if css:
        row.add_css_class(css)
    return row


class GtkStep(Step):
    """One step: a row with a spinner, and its output folded behind it."""

    def __init__(self, add_group: Callable[[Gtk.Widget], None], label: str) -> None:
        super().__init__()
        self._pending: list[str] = []
        self._output: Gtk.Label | None = None
        self._row: Adw.ExpanderRow | None = None
        self._spinner = Gtk.Spinner(spinning=True, valign=Gtk.Align.CENTER)
        GLib.idle_add(self._build, add_group, label)

    def _build(self, add_group: Callable[[Gtk.Widget], None], label: str) -> bool:
        self._row = Adw.ExpanderRow(title=label)
        self._row.set_title_lines(0)
        self._row.add_suffix(self._spinner)

        self._output = Gtk.Label(
            xalign=0,
            selectable=True,
            wrap=True,
            wrap_mode=Pango.WrapMode.WORD_CHAR,
            margin_top=8,
            margin_bottom=8,
            margin_start=12,
            margin_end=12,
            css_classes=["monospace", "dim-label"],
        )
        scroller = Gtk.ScrolledWindow(
            child=self._output, max_content_height=280, propagate_natural_height=True
        )
        self._row.add_row(Adw.ActionRow(child=scroller, activatable=False))

        add_group(self._row)
        self._render()
        return GLib.SOURCE_REMOVE

    def _render(self) -> bool:
        if self._output is not None:
            self._output.set_text("\n".join(self._pending))
        return GLib.SOURCE_REMOVE

    def write(self, line: str) -> None:
        self._pending.append(line)
        GLib.idle_add(self._render)

    def close(self, ok: bool, summary: str) -> None:
        def finish() -> bool:
            if self._row is None:
                return GLib.SOURCE_REMOVE
            self._row.remove(self._spinner)
            self._row.add_suffix(
                Gtk.Label(
                    label=summary,
                    css_classes=["caption", "success" if ok else "error"],
                    valign=Gtk.Align.CENTER,
                )
            )
            # Nothing to expand when the command said nothing.
            self._row.set_enable_expansion(bool(self._pending))
            return GLib.SOURCE_REMOVE

        GLib.idle_add(finish)


class GtkToolUI(ToolUI):
    def __init__(
        self, page: Adw.PreferencesPage, window: Gtk.Window, stop: threading.Event
    ) -> None:
        self._page = page
        self._window = window
        self._stop = stop
        self._group: Adw.PreferencesGroup | None = None

    # -- Building blocks -----------------------------------------------------

    def _add(self, widget: Gtk.Widget) -> None:
        """Append a row, opening an untitled group if no section was declared."""
        if self._group is None:
            self.section("")
        assert self._group is not None
        self._group.add(widget)

    def _later(self, action: Callable[[], None]) -> None:
        """Run a widget change on the main loop, which is the only place GTK allows it."""

        def once() -> bool:
            action()
            return GLib.SOURCE_REMOVE

        GLib.idle_add(once)

    def section(self, title: str) -> None:
        group = Adw.PreferencesGroup(title=title)
        self._group = group
        self._later(lambda: self._page.add(group))

    def fields(self, rows: Sequence[tuple[str, str]]) -> None:
        built = [_wrapping_row(label, value) for label, value in rows]

        def add_all() -> None:
            for row in built:
                self._add(row)

        self._later(add_all)

    def note(self, text: str, level: Level = Level.INFO) -> None:
        row = _wrapping_row(text, css=_NOTE_CLASS[level])
        self._later(lambda: self._add(row))

    def step(self, label: str) -> Step:
        return GtkStep(self._add, label)

    # -- Questions -----------------------------------------------------------

    def choose(self, question: str, options: Sequence[Choice]) -> str | None:
        return dialogs.choose(self._window, question, options)

    def confirm(self, question: str) -> bool:
        return dialogs.confirm(self._window, question)

    def should_stop(self) -> bool:
        return self._stop.is_set()
