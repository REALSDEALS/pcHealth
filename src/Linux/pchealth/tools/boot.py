"""Boot repair for UEFI systems.

UEFI only, deliberately. Repairing a legacy BIOS/MBR setup means writing raw
boot code to the disk -- a different and far riskier operation than
reinstalling an EFI binary onto the ESP.

Every repair runs the bootloader's own official command. pcHealth never writes
boot sectors itself and never guesses which loader you use.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from .. import probe, system
from .base import Choice, Level, ToolUI

ESP_CANDIDATES = ("/efi", "/boot/efi", "/boot")


@dataclass(frozen=True)
class Loader:
    name: str
    present: bool
    commands: list[list[str]]

    @property
    def state(self) -> str:
        return "installed on this ESP" if self.present else "tooling present, not installed here"


def _efi_names() -> tuple[str, str]:
    """The EFI binary name and GRUB target for this machine.

    Both follow the firmware's bitness, not the CPU's: a 64-bit CPU can ship
    32-bit UEFI firmware, and BOOTX64 will not boot there.
    """
    machine = os.uname().machine
    if machine.startswith(("aarch64", "arm64")):
        return "BOOTAA64.EFI", "arm64-efi"
    bits = system.read_text("/sys/firmware/efi/fw_platform_size") or "64"
    if bits == "32":
        return "BOOTIA32.EFI", "i386-efi"
    return "BOOTX64.EFI", "x86_64-efi"


def _find_esp() -> str | None:
    """Only trust a mounted vfat partition.

    Mounting one ourselves would mean picking a candidate by guesswork, on the
    one filesystem where a wrong guess is fatal.
    """
    for candidate in ESP_CANDIDATES:
        if probe.fstype_for(candidate) == "vfat":
            return candidate
    return None


def _detect_loaders(esp: str, efi_name: str, grub_target: str) -> list[Loader]:
    loaders: list[Loader] = []
    esp_path = Path(esp)

    if (esp_path / "EFI/systemd").exists() or system.has("bootctl"):
        loaders.append(
            Loader(
                name="systemd-boot",
                present=(esp_path / "EFI/systemd").exists(),
                commands=[["bootctl", "install", f"--esp-path={esp}"]],
            )
        )

    grub_cmd = next((c for c in ("grub-install", "grub2-install") if system.has(c)), None)
    if grub_cmd:
        # Fedora/RHEL name everything grub2-* and keep the config in /boot/grub2.
        is_grub2 = grub_cmd == "grub2-install"
        mkconfig = "grub2-mkconfig" if is_grub2 else "grub-mkconfig"
        grub_dir = "/boot/grub2" if is_grub2 else "/boot/grub"
        boot_id = system.distro_info()["ID"] or "linux"
        loaders.append(
            Loader(
                name="GRUB",
                present=Path(grub_dir).exists() or (esp_path / "EFI/grub").exists(),
                commands=[
                    [
                        grub_cmd,
                        f"--target={grub_target}",
                        f"--efi-directory={esp}",
                        f"--bootloader-id={boot_id}",
                    ],
                    [mkconfig, "-o", str(Path(grub_dir) / "grub.cfg")],
                ],
            )
        )

    # Limine has no upstream UEFI installer -- the documented procedure is to
    # copy the EFI binary onto the ESP. Distros ship a helper, so prefer that.
    helper = next((c for c in ("limine-update", "limine-install") if system.has(c)), None)
    limine_source = Path("/usr/share/limine") / efi_name
    if helper or limine_source.exists():
        if helper:
            commands = [[helper]]
        else:
            # Never `limine bios-install` here: that writes an MBR stage and is
            # documented as BIOS-only.
            commands = [
                ["mkdir", "-p", str(esp_path / "EFI/BOOT")],
                ["cp", str(limine_source), str(esp_path / "EFI/BOOT" / efi_name)],
            ]
        configs = ("limine.conf", "limine/limine.conf", "boot/limine/limine.conf")
        loaders.append(
            Loader(
                name="Limine",
                present=(esp_path / "EFI/BOOT" / efi_name).exists()
                or any((esp_path / name).exists() for name in configs),
                commands=commands,
            )
        )

    return loaders


def boot_repair(ui: ToolUI) -> None:
    ui.section("Boot Repair")
    ui.note(
        "This modifies boot-critical files. Incorrect use can render the "
        "system unbootable. Only proceed if you understand what you are doing.",
        Level.WARN,
    )

    # On ostree systems the bootloader entries are generated from the
    # deployments. Reinstalling by hand fights whatever produced them.
    if system.is_image_based():
        ui.note("This is an image-based system (ostree).", Level.ERROR)
        ui.note("Its bootloader belongs to the deployment. Roll back instead: rpm-ostree rollback")
        return

    if not Path("/sys/firmware/efi").exists():
        ui.note("This system booted in legacy BIOS mode (no /sys/firmware/efi).", Level.ERROR)
        ui.note("pcHealth only repairs UEFI bootloaders.")
        return

    efi_name, grub_target = _efi_names()
    esp = _find_esp()
    if not esp:
        ui.note("No mounted EFI System Partition at /efi, /boot/efi or /boot.", Level.ERROR)
        ui.note("Mount it first, then run this tool again.")
        listing = system.output(["lsblk", "-o", "NAME,SIZE,FSTYPE,PARTTYPENAME,MOUNTPOINT"]) or ""
        candidates = [
            line for line in listing.splitlines() if "EFI System" in line or "vfat" in line
        ]
        if candidates:
            ui.fields([(line.split()[0], line) for line in candidates])
        return

    bits = system.read_text("/sys/firmware/efi/fw_platform_size") or "64"
    ui.fields(
        [
            ("Firmware", f"UEFI ({bits}-bit, {os.uname().machine})"),
            ("ESP", esp),
            ("EFI binary", efi_name),
        ]
    )

    loaders = _detect_loaders(esp, efi_name, grub_target)
    if not loaders:
        ui.note("No supported bootloader found (systemd-boot, GRUB or Limine).", Level.ERROR)
        ui.note("Install your bootloader's package first, then run this tool again.")
        return

    choice = ui.choose(
        "Which bootloader should be repaired?",
        [Choice(loader.name, loader.name, loader.state, destructive=True) for loader in loaders],
    )
    if choice is None:
        return
    loader = next(candidate for candidate in loaders if candidate.name == choice)

    ui.section("These commands will run as root")
    ui.fields([(f"{n}.", " ".join(command)) for n, command in enumerate(loader.commands, 1)])

    # Two confirmations, same as the Windows tool: this is the one place where
    # a mistaken click leaves the machine unbootable.
    if not ui.confirm(f"Reinstall {loader.name} on {esp}?"):
        return
    if not ui.confirm("Last chance. An interrupted repair can leave this machine unbootable."):
        return

    # stop_on_error so grub-mkconfig never runs after grub-install failed.
    # efibootmgr rides along: a copied EFI binary with no firmware boot entry
    # still leaves an unbootable machine.
    commands: list[tuple[str, list[str]]] = [
        (" ".join(command), list(command)) for command in loader.commands
    ]
    show_entries = system.has("efibootmgr")
    if show_entries:
        commands.append(("Reading firmware boot entries", ["efibootmgr"]))

    results = ui.run_all(commands, root=True, stop_on_error=True)
    repaired = len(results) >= len(loader.commands) and all(
        result.ok for result in results[: len(loader.commands)]
    )

    if not repaired:
        ui.note("The repair stopped at a failing command.", Level.ERROR)
        ui.note(
            "The system may still boot from its existing entry. Do not reboot "
            "until you have resolved this, and keep a live USB to hand.",
            Level.WARN,
        )
        return

    ui.note(f"{loader.name} reinstalled on {esp}.", Level.OK)
    if show_entries and len(results) > len(loader.commands):
        entries = results[-1].stdout.splitlines()
        ui.section("Firmware boot entries")
        ui.fields([(line.split()[0].rstrip("*"), line) for line in entries if line.strip()])
    ui.note("Verify the entry above before rebooting.", Level.WARN)
