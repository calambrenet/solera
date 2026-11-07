#!/usr/bin/python3
"""Migrate stale per-user Solera Update state to the system extension."""

import ast
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


UUID = "solera-update@soleralinux.org"
SYSTEM_EXTENSION = Path("/usr/share/gnome-shell/extensions") / UUID
USER_EXTENSION = Path.home() / ".local/share/gnome-shell/extensions" / UUID
BACKUP_ROOT = Path.home() / ".local/share/solera/extension-backups"
MARKER = Path.home() / ".local/state/solera/migrations/solera-update-gnome51-v1.done"
GSETTINGS = "/usr/bin/gsettings"
GNOME_SHELL_VERSION = "/usr/bin/gnome-extensions"


def _run_gsettings(*args):
    return subprocess.run(
        [GSETTINGS, *args], check=True, text=True, capture_output=True
    ).stdout.strip()


def _get_extension_list(key):
    raw = _run_gsettings("get", "org.gnome.shell", key)
    if raw == "@as []":
        return []
    value = ast.literal_eval(raw)
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        raise ValueError(f"Unexpected value for {key}: {raw}")
    return value


def _set_extension_list(key, values):
    _run_gsettings("set", "org.gnome.shell", key, repr(values))


def _current_shell_major():
    version = subprocess.run(
        [GNOME_SHELL_VERSION, "--version"],
        check=True,
        text=True,
        capture_output=True,
    ).stdout
    match = re.search(r"\d+", version)
    if not match:
        raise ValueError(f"Cannot parse GNOME Shell version: {version.strip()}")
    return match.group(0)


def _read_metadata(path):
    with (path / "metadata.json").open(encoding="utf-8") as metadata_file:
        return json.load(metadata_file)


def _backup_stale_copy(system_metadata, shell_major):
    if not USER_EXTENSION.exists():
        return False

    try:
        user_metadata = _read_metadata(USER_EXTENSION)
        user_version = int(user_metadata.get("version", 0))
        system_version = int(system_metadata.get("version", 0))
        supported_versions = [
            str(version) for version in user_metadata.get("shell-version", [])
        ]
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        user_metadata = {}
        user_version = 0
        system_version = int(system_metadata.get("version", 0))
        supported_versions = []

    stale = user_version < system_version or shell_major not in supported_versions
    if not stale:
        return False

    backup_version = user_version or "unknown"
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = BACKUP_ROOT / f"solera-update-v{backup_version}-{timestamp}"
    BACKUP_ROOT.mkdir(parents=True, exist_ok=True)
    shutil.move(str(USER_EXTENSION), str(backup))
    print(f"solera-update-migration: backed up stale user extension to {backup}")
    return True


def _write_marker():
    MARKER.parent.mkdir(parents=True, exist_ok=True)
    temporary = MARKER.with_name(f"{MARKER.name}.{os.getpid()}.tmp")
    temporary.write_text("completed\n", encoding="utf-8")
    temporary.replace(MARKER)


def main():
    # GDM and system accounts must not receive per-user desktop migrations.
    if os.getuid() < 1000:
        return 0
    if MARKER.exists():
        return 0
    if not (SYSTEM_EXTENSION / "metadata.json").is_file():
        raise FileNotFoundError(f"System extension is missing: {SYSTEM_EXTENSION}")

    system_metadata = _read_metadata(SYSTEM_EXTENSION)
    shell_major = _current_shell_major()
    if shell_major not in [
        str(version) for version in system_metadata.get("shell-version", [])
    ]:
        raise RuntimeError(
            f"System Solera Update does not declare support for GNOME {shell_major}"
        )

    _backup_stale_copy(system_metadata, shell_major)

    enabled = _get_extension_list("enabled-extensions")
    disabled = _get_extension_list("disabled-extensions")
    new_enabled = [item for item in enabled if item != UUID]
    new_enabled.append(UUID)
    new_disabled = [item for item in disabled if item != UUID]

    if new_enabled != enabled:
        _set_extension_list("enabled-extensions", new_enabled)
    if new_disabled != disabled:
        _set_extension_list("disabled-extensions", new_disabled)

    _write_marker()
    print("solera-update-migration: system extension enabled for this user")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:  # Logged by the unit; no marker means retry.
        print("solera-update-migration: " + str(error), file=sys.stderr)
        raise SystemExit(1)
