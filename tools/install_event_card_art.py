#!/usr/bin/env python3
"""Install the 2026-10-14 approved event-card PNGs into this Godot checkout.

Usage (Windows PowerShell, from the Godot project root):
    py tools/install_event_card_art.py "$env:USERPROFILE\\Downloads\\necromancer_event_card_assets_20261014.zip"

This only copies vetted runtime PNGs. It never commits, pushes or deletes source assets.
"""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import sys
import zipfile

REPO_ROOT = Path(__file__).resolve().parents[1]
APPROVED_FILES = (
    "assets/map/ui/discovery_card_base.png",
    "assets/map/events/discovery_hill.png",
    "assets/map/events/discovery_rest.png",
    "assets/map/events/discovery_graveyard.png",
    "assets/map/events/discovery_world_tree.png",
    "assets/map/events/discovery_altar.png",
    "assets/map/events/routine_wounded_soldier.png",
)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def install(archive: Path, root: Path = REPO_ROOT) -> list[str]:
    if not archive.is_file():
        raise ValueError(f"Asset ZIP not found: {archive}")
    with zipfile.ZipFile(archive) as zipped:
        found = set(zipped.namelist())
        missing = [name for name in APPROVED_FILES if name not in found]
        if missing:
            raise ValueError("Missing approved asset files: " + ", ".join(missing))
        planned: list[tuple[Path, bytes]] = []
        for name in APPROVED_FILES:
            item = zipped.getinfo(name)
            if item.is_dir() or item.file_size > 12_000_000:
                raise ValueError(f"Invalid asset size/path: {name}")
            data = zipped.read(name)
            if not data.startswith(PNG_SIGNATURE):
                raise ValueError(f"Invalid PNG signature: {name}")
            destination = root.joinpath(*name.split("/"))
            if destination.exists():
                if hashlib.sha256(destination.read_bytes()).digest() != hashlib.sha256(data).digest():
                    raise ValueError(f"Refusing to overwrite a different existing asset: {destination}")
                print(f"already installed: {name}")
                continue
            planned.append((destination, data))
    # Validate ALL files before writing ANY. Intended for fresh installation.
    for dest, data in planned:
        dest.parent.mkdir(parents=True, exist_ok=True)
        temp = dest.with_name(dest.name + ".tmp")
        if temp.exists():
            raise ValueError(f"Temporary staging file exists: {temp}")
        try:
            with temp.open("xb") as out:
                out.write(data)
                out.flush()
                os.fsync(out.fileno())
            temp.replace(dest)
        except Exception:
            if temp.exists():
                temp.unlink()
            raise
        print(f"installed: {dest.relative_to(root)} ({len(data)} bytes)")
    return [str(dest.relative_to(root)) for dest, _ in planned]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, help="Approved ZIP bundle")
    args = parser.parse_args()
    try:
        files = install(args.archive.expanduser().resolve())
    except (ValueError, OSError, zipfile.BadZipFile, RuntimeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(f"Ready: {len(files)} new PNG(s). Open Godot to import resources.")
    print("Review with: git status --short -- assets/map/events assets/map/ui")
    print("No automatic git commit or push performed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
