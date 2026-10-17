"""The terminal rendering of a tool.

Here the structural calls become text: a section is a heading, fields are an
aligned block, a step prints its label and its output. The GTK front-end takes
the same calls and builds widgets instead.
"""

from __future__ import annotations

from collections.abc import Sequence

from ..tools.base import Cancelled, Choice, Level, Step, ToolUI
from . import theme

_STYLE = {
    Level.INFO: "info",
    Level.OK: "ok",
    Level.WARN: "warn",
    Level.ERROR: "error",
}


class TerminalStep(Step):
    def write(self, line: str) -> None:
        theme.write(f"      {line}", "muted")

    def close(self, ok: bool, summary: str) -> None:
        theme.write(f"    {summary}", "ok" if ok else "error")


class TerminalUI(ToolUI):
    def section(self, title: str) -> None:
        theme.write()
        theme.write(f"  {title}", "head")

    def fields(self, rows: Sequence[tuple[str, str]]) -> None:
        if not rows:
            return
        width = max(len(label) for label, _ in rows)
        for label, value in rows:
            theme.write(f"    {label.ljust(width)}   {value}")

    def note(self, text: str, level: Level = Level.INFO) -> None:
        theme.write(f"    {text}", _STYLE[level] if level is not Level.INFO else "muted")

    def step(self, label: str) -> Step:
        theme.write(f"    {label}...", "info")
        return TerminalStep()

    def choose(self, question: str, options: Sequence[Choice]) -> str | None:
        while True:
            theme.write()
            for index, option in enumerate(options, start=1):
                theme.option(str(index), option.label, option.detail)
            theme.option("B", "Back")
            theme.write()

            answer = self._prompt(question).strip()
            if answer.upper() == "B":
                return None
            if answer.isdigit() and 1 <= int(answer) <= len(options):
                return options[int(answer) - 1].key
            theme.write("Invalid choice.", "error")

    def confirm(self, question: str) -> bool:
        return self._prompt(f"{question} (y/n)").strip().lower() in ("y", "yes")

    @staticmethod
    def _prompt(text: str) -> str:
        try:
            return input(f"  {text}: ")
        except EOFError as exc:
            raise Cancelled("no input available") from exc
