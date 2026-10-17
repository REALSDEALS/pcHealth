"""Questions a tool asks, rendered as dialogs.

A tool runs off the main loop, but GTK may only be touched from it. Each
helper therefore hops to the main loop, shows the dialog, and blocks the
worker on an Event until the answer comes back.
"""

from __future__ import annotations

import threading
from collections.abc import Sequence
from typing import Any

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, GLib, Gtk  # noqa: E402

from ..tools import Choice  # noqa: E402

# Adw.AlertDialog arrived in libadwaita 1.5 and replaced Adw.MessageDialog.
# Distros ship both, so pick whichever this system actually has.
_ALERT = getattr(Adw, "AlertDialog", None) or Adw.MessageDialog
_USES_ALERT_DIALOG = hasattr(Adw, "AlertDialog")

_CANCEL = "__cancel__"


def _ask(
    parent: Gtk.Window,
    heading: str,
    body: str,
    responses: Sequence[tuple[str, str, bool]],
) -> str:
    """Show a dialog with one button per response and wait for the answer.

    Each response is (id, label, destructive). Runs from a worker thread.
    """
    done = threading.Event()
    answer = _CANCEL

    def build() -> bool:
        dialog = _ALERT(heading=heading, body=body)
        dialog.add_response(_CANCEL, "Cancel")
        for response_id, label, destructive in responses:
            dialog.add_response(response_id, label)
            appearance = (
                Adw.ResponseAppearance.DESTRUCTIVE
                if destructive
                else Adw.ResponseAppearance.SUGGESTED
            )
            dialog.set_response_appearance(response_id, appearance)
        dialog.set_default_response(responses[-1][0] if responses else _CANCEL)
        dialog.set_close_response(_CANCEL)

        def on_response(_dialog: Any, response: str) -> None:
            nonlocal answer
            answer = response
            done.set()

        dialog.connect("response", on_response)
        if _USES_ALERT_DIALOG:
            dialog.present(parent)
        else:
            dialog.set_transient_for(parent)
            dialog.present()
        return GLib.SOURCE_REMOVE

    GLib.idle_add(build)
    done.wait()
    return answer


def confirm(parent: Gtk.Window, question: str) -> bool:
    return _ask(parent, "pcHealth", question, [("ok", "Continue", True)]) == "ok"


def choose(parent: Gtk.Window, question: str, options: Sequence[Choice]) -> str | None:
    """One button per option -- never a text box asking for a number."""
    body = "\n".join(f"{o.label} — {o.detail}" if o.detail else o.label for o in options)
    answer = _ask(
        parent,
        question,
        body,
        [(option.key, option.label, option.destructive) for option in options],
    )
    return None if answer == _CANCEL else answer
