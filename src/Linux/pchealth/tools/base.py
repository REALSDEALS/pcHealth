"""What a tool is, and what it may say.

A tool describes results. It does not print lines, draw menus or format
output, because those are decisions only a front-end can make: the terminal
writes text, the GTK window builds rows, cards and progress bars. The moment a
tool emits "[>>] Doing something..." it has decided it lives in a terminal,
and the GUI can do no better than show you that text -- which is exactly what
a GUI should not be.

So the vocabulary is small and structural:

    ui.section("Battery")                    a heading
    ui.fields([("Health", "94%")])           label/value rows
    ui.note("No battery detected", WARN)     one message
    ui.run(argv, label="Trimming")           a step, with its raw output
    ui.choose(...) / ui.confirm(...)         a question

Raw command output goes with the step that produced it, where a front-end can
tuck it away. In the terminal it is printed; in the window it sits behind a
"Details" expander, because most of the time nobody wants to read it.
"""

from __future__ import annotations

import re
import time
from abc import ABC, abstractmethod
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from enum import Enum

from .. import system


class Level(Enum):
    INFO = "info"
    OK = "ok"
    WARN = "warn"
    ERROR = "error"


class Cancelled(Exception):
    """Raised when the user backs out of a prompt. Never an error."""


@dataclass(frozen=True)
class Choice:
    """One option a tool offers. `key` identifies it in the tool's own code."""

    key: str
    label: str
    detail: str = ""
    # Marks an option that reboots, reinstalls or otherwise cannot be undone,
    # so a front-end can style it as destructive.
    destructive: bool = False


# "Downloading…: 41.4%", "Installing: 7%", "  Progress: 100.0 %"
_PROGRESS = re.compile(r"^\s*\S.*?[:\s]\s*\d{1,3}(?:[.,]\d+)?\s*%\s*$")


class Step(ABC):
    """A running piece of work, with the command output it produces.

    fwupd, apt and dnf redraw a progress line with carriage returns; through a
    pipe that becomes hundreds of separate lines. Thinning them out belongs
    here rather than in every tool that happens to run such a command.
    """

    def __init__(self, interval: float = 1.0) -> None:
        self._interval = interval
        self._last = 0.0
        self._held: str | None = None

    def output(self, line: str) -> None:
        if not _PROGRESS.match(line):
            self._flush()
            self.write(line)
            return
        now = time.monotonic()
        if now - self._last >= self._interval:
            self._last, self._held = now, None
            self.write(line)
        else:
            self._held = line

    def _flush(self) -> None:
        if self._held is not None:
            self.write(self._held)
            self._held = None

    def finish(self, ok: bool, summary: str = "") -> None:
        self._flush()
        self.close(ok, summary)

    @abstractmethod
    def write(self, line: str) -> None:
        """Record one line of raw output."""

    @abstractmethod
    def close(self, ok: bool, summary: str) -> None:
        """Mark the step finished."""


class ToolUI(ABC):
    """Everything a tool is allowed to do. Implemented per front-end."""

    @abstractmethod
    def section(self, title: str) -> None: ...

    @abstractmethod
    def fields(self, rows: Sequence[tuple[str, str]]) -> None: ...

    @abstractmethod
    def note(self, text: str, level: Level = Level.INFO) -> None: ...

    @abstractmethod
    def step(self, label: str) -> Step: ...

    @abstractmethod
    def choose(self, question: str, options: Sequence[Choice]) -> str | None: ...

    @abstractmethod
    def confirm(self, question: str) -> bool: ...

    def should_stop(self) -> bool:
        return False

    # -- Running commands ----------------------------------------------------
    # Every tool used to repeat the same six lines around each command: print a
    # label, stream the output with an indent, check the exit code, print OK or
    # a failure. That lives here now.

    def run(
        self,
        argv: Sequence[str],
        *,
        label: str,
        root: bool = False,
        ok: str = "Done",
        failed: str = "",
    ) -> system.Result:
        """Run one command as a step."""
        return self.run_all([(label, list(argv))], root=root, ok=ok, failed=failed)[0]

    def run_all(
        self,
        steps: Sequence[tuple[str, Sequence[str]]],
        *,
        root: bool = False,
        stop_on_error: bool = False,
        ok: str = "Done",
        failed: str = "",
    ) -> list[system.Result]:
        """Run several commands, elevating once for the lot.

        pkexec authenticates per invocation, so elevating each command
        separately asked for the password once per command.
        """
        if not steps:
            return []

        opened: dict[int, Step] = {}

        def on_line(index: int, line: str) -> None:
            if index not in opened:
                opened[index] = self.step(steps[index][0])
            opened[index].output(line)

        if root:
            results = system.run_root_batch(
                [argv for _, argv in steps], on_line=on_line, stop_on_error=stop_on_error
            )
        else:
            results = []
            for index, (_, argv) in enumerate(steps):

                def forward(line: str, i: int = index) -> None:
                    on_line(i, line)

                code = system.stream(list(argv), forward)
                results.append(system.Result(code))
                if stop_on_error and code != 0:
                    break

        for index, result in enumerate(results):
            step = opened.get(index) or self.step(steps[index][0])
            summary = ok if result.ok else (failed or f"Exit code {result.returncode}")
            step.finish(result.ok, summary)
        return results


ToolFunc = Callable[[ToolUI], None]
