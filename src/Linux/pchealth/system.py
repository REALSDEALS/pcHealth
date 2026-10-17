"""Process, privilege and platform helpers.

This is the Linux counterpart of the PowerShell CLI's Helpers.ps1. The rules
that shaped that file apply here too: a missing command is the normal case, not
an edge case. Containers and WSL have no systemd, minimal installs have no
lspci or smartctl, and an image-based system has no package manager to speak of.
Every helper here returns None or an empty result instead of raising.
"""

from __future__ import annotations

import json
import os
import pwd
import shutil
import subprocess
import sys
import webbrowser
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from pathlib import Path

# Returned when the command itself could not be found, matching the shell
# convention so callers can treat it like any other failing exit code.
COMMAND_NOT_FOUND = 127


@dataclass(frozen=True)
class Result:
    returncode: int
    stdout: str = ""
    stderr: str = ""

    @property
    def ok(self) -> bool:
        return self.returncode == 0


def which(command: str) -> str | None:
    return shutil.which(command)


def has(command: str) -> bool:
    return shutil.which(command) is not None


def run(
    argv: Sequence[str],
    *,
    timeout: float | None = None,
    stdin_text: str | None = None,
    env: dict[str, str] | None = None,
) -> Result:
    """Run a command and capture its output. Never raises on a missing binary."""
    if not argv or not has(argv[0]):
        return Result(COMMAND_NOT_FOUND, "", f"{argv[0] if argv else '<empty>'}: not found")
    try:
        completed = subprocess.run(
            list(argv),
            capture_output=True,
            text=True,
            timeout=timeout,
            input=stdin_text,
            env=env,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return Result(124, "", f"{argv[0]}: timed out after {timeout}s")
    except OSError as exc:
        return Result(COMMAND_NOT_FOUND, "", f"{argv[0]}: {exc}")
    return Result(completed.returncode, completed.stdout, completed.stderr)


def output(argv: Sequence[str], *, timeout: float | None = None) -> str | None:
    """Trimmed stdout, or None when the command is missing, fails or says nothing.

    The PowerShell side learned this the hard way: `(& cmd args).Trim()` throws
    on a missing command and aborts the whole tool rather than one field.
    """
    result = run(argv, timeout=timeout)
    if not result.ok:
        return None
    text = result.stdout.strip()
    return text or None


def stream(
    argv: Sequence[str],
    on_line: Callable[[str], None],
    *,
    timeout: float | None = None,
    should_stop: Callable[[], bool] | None = None,
) -> int:
    """Run a command, handing each output line to on_line as it arrives.

    Long-running tools (fstrim, fwupdmgr, a package upgrade) must not look
    frozen, so stdout and stderr are merged and forwarded line by line rather
    than collected and printed at the end.
    """
    if not argv or not has(argv[0]):
        on_line(f"{argv[0] if argv else '<empty>'}: not found")
        return COMMAND_NOT_FOUND
    try:
        process = subprocess.Popen(
            list(argv),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
    except OSError as exc:
        on_line(f"{argv[0]}: {exc}")
        return COMMAND_NOT_FOUND

    assert process.stdout is not None
    try:
        for line in process.stdout:
            on_line(line.rstrip("\n"))
            if should_stop is not None and should_stop():
                process.terminate()
                break
        return process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        process.kill()
        on_line(f"{argv[0]}: timed out after {timeout}s")
        return 124
    except KeyboardInterrupt:
        process.terminate()
        raise
    finally:
        process.stdout.close()


# -- Privilege ----------------------------------------------------------------


def is_root() -> bool:
    return os.geteuid() == 0


def elevated(argv: Sequence[str]) -> list[str]:
    """Prefix a command with whatever will elevate it, or leave it alone.

    The GUI must never run as root -- on Wayland a root process cannot reach
    the user's display, and a root-owned toolkit is a security problem on its
    own. So privilege is raised per action instead of per session: pkexec when
    polkit is available, sudo as the fallback for a terminal-only system.
    """
    if is_root():
        return list(argv)
    if has("pkexec"):
        return ["pkexec", *argv]
    if has("sudo"):
        return ["sudo", *argv]
    return list(argv)


def run_root(argv: Sequence[str], *, timeout: float | None = None) -> Result:
    return run(elevated(argv), timeout=timeout)


def stream_root(
    argv: Sequence[str],
    on_line: Callable[[str], None],
    *,
    timeout: float | None = None,
    should_stop: Callable[[], bool] | None = None,
) -> int:
    return stream(elevated(argv), on_line, timeout=timeout, should_stop=should_stop)


# -- Platform -----------------------------------------------------------------


def kernel_release() -> str:
    return os.uname().release


def kernel_major() -> int | None:
    head = kernel_release().split(".", 1)[0]
    try:
        return int(head)
    except ValueError:
        return None


def read_text(path: str | Path) -> str | None:
    """Read a sysfs or procfs file. Absent and unreadable are both normal."""
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return None


def distro_info() -> dict[str, str]:
    """Parse /etc/os-release. ID and ID_LIKE are lowercased, names keep casing."""
    info: dict[str, str] = {}
    raw = read_text("/etc/os-release")
    for line in (raw or "").splitlines():
        key, sep, value = line.partition("=")
        if not sep or not key.isidentifier():
            continue
        info[key] = value.strip().strip('"').strip("'")

    info["ID"] = info.get("ID", "").lower()
    info["ID_LIKE"] = info.get("ID_LIKE", "").lower()
    info.setdefault("NAME", "Linux")
    info.setdefault("PRETTY_NAME", info["NAME"])
    return info


def is_image_based() -> bool:
    """True on ostree systems: Silverblue, Bazzite, Kinoite, openSUSE MicroOS.

    /usr is read-only there and the bootloader belongs to the deployment, so
    tools that manage packages or boot files are hidden rather than taught a
    second dialect -- bootc and rpm-ostree own that work.
    """
    return Path("/run/ostree-booted").exists() or Path("/ostree").exists()


@dataclass(frozen=True)
class DesktopUser:
    name: str
    uid: str
    home: str
    dbus: str


def desktop_user() -> DesktopUser | None:
    """Resolve the human behind the session, not the root the tool runs as.

    Under sudo or pkexec the process environment describes root, so anything
    touching the desktop session -- audio, topgrade, the thumbnail cache, log
    off -- has to ask who actually logged in. The passwd database answers that
    through the pwd module; shelling out to id and getent for the same three
    fields only added three ways to fail.
    """
    try:
        if name := os.environ.get("SUDO_USER"):
            entry = pwd.getpwnam(name)
        elif (uid := os.environ.get("PKEXEC_UID", "")).isdigit():
            entry = pwd.getpwuid(int(uid))
        else:
            entry = pwd.getpwuid(os.getuid())
    except (KeyError, OSError):
        return None

    # The session bus `systemctl --user` needs. An inherited address is passed
    # on to `env` as key=value, so reject anything that is not a D-Bus
    # transport and derive the standard path instead.
    dbus = os.environ.get("DBUS_SESSION_BUS_ADDRESS", "")
    if not dbus.startswith(("unix:", "tcp:", "nonce-tcp:", "autolaunch:")):
        dbus = f"unix:path=/run/user/{entry.pw_uid}/bus"

    return DesktopUser(name=entry.pw_name, uid=str(entry.pw_uid), home=entry.pw_dir, dbus=dbus)


def run_as_user(user: DesktopUser, argv: Sequence[str]) -> Result:
    """Run a command as the desktop user, with their session bus.

    Usually there is nothing to drop to. The GUI already runs as that user --
    it must never run as root -- so wrapping the call in sudo would ask for a
    password that `systemctl --user` does not need, which is exactly the kind
    of prompt this codebase keeps trying to get rid of. Only a process that
    really is root has to switch back, and a machine with polkit but no sudo
    still has a way through.
    """
    session = {**os.environ, "DBUS_SESSION_BUS_ADDRESS": user.dbus}

    if str(os.getuid()) == user.uid:
        return run(argv, env=session)

    # Switching user means a new process environment, so the session bus is
    # passed as an argument to env rather than inherited. Each value is its own
    # argv token and never shell text, so a hostile DISPLAY cannot become a
    # command.
    bus = f"DBUS_SESSION_BUS_ADDRESS={user.dbus}"
    if has("sudo"):
        return run(["sudo", "-u", user.name, "env", bus, *argv])
    if has("pkexec"):
        return run(["pkexec", "--user", user.name, "env", bus, *argv])
    return Result(COMMAND_NOT_FOUND, "", "Neither sudo nor pkexec is available.")


# -- Package manager ----------------------------------------------------------


@dataclass(frozen=True)
class PackageManager:
    cmd: str
    refresh: list[str] | None
    list_updates: list[str]
    update: list[str]
    install: list[str]
    # Verify names its own command: rpm and debsums do the checking, not the
    # manager itself.
    verify: list[str] = field(default_factory=list)


_DEFINITIONS: dict[str, PackageManager] = {
    "apt": PackageManager(
        "apt",
        ["update"],
        ["list", "--upgradable"],
        ["upgrade", "-y"],
        ["install", "-y"],
        ["debsums", "-s"],
    ),
    "dnf": PackageManager(
        "dnf", None, ["check-update"], ["upgrade", "-y"], ["install", "-y"], ["rpm", "-Va"]
    ),
    "pacman": PackageManager(
        "pacman",
        ["-Sy"],
        ["-Qu"],
        ["-Syu", "--noconfirm"],
        ["-S", "--noconfirm"],
        ["pacman", "-Qkk"],
    ),
    "zypper": PackageManager(
        "zypper", ["refresh"], ["list-updates"], ["update", "-y"], ["install", "-y"], ["rpm", "-Va"]
    ),
}

_FAMILIES: tuple[tuple[tuple[str, ...], str], ...] = (
    (("debian", "ubuntu", "mint", "linuxmint", "pop", "elementary", "zorin", "kali"), "apt"),
    (("fedora", "rhel", "centos", "almalinux", "rocky"), "dnf"),
    (("arch", "cachyos", "manjaro", "endeavouros", "artix", "garuda"), "pacman"),
    (("suse", "sles", "opensuse"), "zypper"),
)


def package_manager() -> PackageManager | None:
    """Pick the manager by distro family, never by which binary is on PATH.

    A Distrobox export or Homebrew readily puts apt and pacman on a Fedora box,
    and picking the first one found would run Debian commands against an rpm
    system.
    """
    info = distro_info()
    family = f"{info['ID']} {info['ID_LIKE']}"

    name: str | None = None
    for keys, manager in _FAMILIES:
        if any(key in family for key in keys):
            name = manager
            break

    if name is None:
        # Unrecognised distro: fall back to whatever is actually installed.
        name = next((key for key in sorted(_DEFINITIONS) if has(key)), None)

    if name is None or not has(name):
        return None
    return _DEFINITIONS[name]


def open_url(url: str) -> bool:
    """Open a URL in the desktop user's browser.

    webbrowser is the standard library's own launcher and knows the desktop
    handler, a $BROWSER setting and the plain browsers besides, so it succeeds
    on systems where xdg-open is not installed at all. Root is the exception:
    its browser would open into a session that may not even accept it, so the
    URL goes back to the user who logged in, the way the audio and topgrade
    tools do.
    """
    if not url.startswith(("http://", "https://")):
        return False

    user = desktop_user()
    if is_root() and user and user.name != "root" and has("sudo"):
        return run_as_user(user, ["xdg-open", url]).ok
    return webbrowser.open(url)


def _helper_argv() -> list[str]:
    """pkexec clears the environment, so the helper is run as a plain path."""
    return [sys.executable, str(Path(__file__).resolve().parent / "privileged.py")]


def run_root_batch(
    commands: Sequence[Sequence[str]],
    on_line: Callable[[int, str], None] | None = None,
    *,
    stop_on_error: bool = False,
) -> list[Result]:
    """Run several commands as root, asking for the password once.

    Every caller that needs more than one privileged command should use this.
    Six separate run_root calls means six pkexec prompts, which is what made
    the Health page unusable.

    on_line receives (index, line) as output arrives, so a long-running batch
    still shows progress.
    """
    batch = [list(command) for command in commands]
    if not batch:
        return []

    if is_root():
        results = []
        for index, argv in enumerate(batch):
            if on_line is None:
                results.append(run(argv))
            else:
                collected: list[str] = []

                def collect(line: str, sink: list[str] = collected, i: int = index) -> None:
                    sink.append(line)
                    on_line(i, line)

                rc = stream(argv, collect)
                results.append(Result(rc, "\n".join(collected)))
            if stop_on_error and not results[-1].ok:
                break
        return results

    payload = json.dumps({"commands": batch, "stop_on_error": stop_on_error})
    output: list[list[str]] = [[] for _ in batch]
    codes: list[int] = [COMMAND_NOT_FOUND] * len(batch)

    # Fixed argv, no shell: the batch travels on stdin as JSON.
    process = subprocess.Popen(
        elevated(_helper_argv()),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,
    )
    assert process.stdin is not None and process.stdout is not None
    try:
        process.stdin.write(payload)
        process.stdin.close()
        for raw in process.stdout:
            try:
                event = json.loads(raw)
            except json.JSONDecodeError:
                continue
            index = event.get("i")
            if not isinstance(index, int) or not 0 <= index < len(batch):
                continue
            if "line" in event:
                output[index].append(str(event["line"]))
                if on_line is not None:
                    on_line(index, str(event["line"]))
            elif "exit" in event:
                codes[index] = int(event["exit"])
    finally:
        process.stdout.close()
        process.wait()

    return [Result(code, "\n".join(lines)) for code, lines in zip(codes, output, strict=True)]
