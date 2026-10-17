#!/usr/bin/env python3
"""Runs a batch of commands as root, from a single elevation prompt.

pkexec authenticates per invocation, so a tool that ran six privileged
commands asked for the password six times. This helper is elevated once and
then runs the whole batch, streaming each line back as it arrives.

It is deliberately dumb: it holds no logic, takes no decisions, and runs
exactly the argv lists it is handed on stdin as JSON. No shell is involved, so
nothing in a filename or a package name can become a command. It exits as soon
as the batch is done -- there is no long-lived root process listening on a
pipe.

Standard library only, and no imports from the pchealth package: pkexec clears
the environment, so this file has to work when run as a bare path.
"""

from __future__ import annotations

import json
import subprocess
import sys
from typing import TypeGuard

EXIT_BAD_PAYLOAD = 2


def _emit(event: dict[str, object]) -> None:
    sys.stdout.write(json.dumps(event) + "\n")
    sys.stdout.flush()


def _valid(batch: object) -> TypeGuard[list[list[str]]]:
    return isinstance(batch, list) and all(
        isinstance(argv, list) and argv and all(isinstance(part, str) for part in argv)
        for argv in batch
    )


def main() -> int:
    try:
        payload = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, UnicodeDecodeError):
        return EXIT_BAD_PAYLOAD
    if not isinstance(payload, dict):
        return EXIT_BAD_PAYLOAD

    batch = payload.get("commands")
    # Boot repair must not run grub-mkconfig after grub-install failed, so a
    # batch can ask to stop at the first non-zero exit.
    stop_on_error = bool(payload.get("stop_on_error"))
    if not _valid(batch):
        return EXIT_BAD_PAYLOAD

    for index, argv in enumerate(batch):
        try:
            # argv is a validated list of strings and no shell is involved.
            process = subprocess.Popen(
                argv,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
        except OSError as exc:
            _emit({"i": index, "exit": 127, "error": str(exc)})
            continue

        assert process.stdout is not None
        with process.stdout:
            for line in process.stdout:
                _emit({"i": index, "line": line.rstrip("\n")})
        code = process.wait()
        _emit({"i": index, "exit": code})
        if code != 0 and stop_on_error:
            break

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
