#!/usr/bin/env python3
"""P5-01: fail closed if Godot runtime directly depends on the legacy web repo.

Scope is Godot gameplay/resource inputs, *not* documentation, developer tests,
export presets, or the mobile-only post-export web/landscape-lock shell.
No runtime data is downloaded or changed by this check.
"""
from __future__ import annotations

import argparse
import re
import sys
import tempfile
from pathlib import Path

SUFFIXES = {".gd", ".tscn", ".tres", ".gdshader", ".shader", ".json", ".cfg", ".gdextension"}
RUNTIME_DIRS = ("systems", "data", "assets")
# Anchored project-root references, not comments about migration history.
FORBIDDEN = (
    ("legacy source repository", re.compile(r"necromancer-dice-board|reference/html-final", re.I)),
    ("external HTTP(S)/FTP data", re.compile(r"\b(?:https?|ftp)://", re.I)),
    ("HTML/JS/CSS asset", re.compile(r"(?:res://|(?:\.\./)+|['\"]/?web/)[^\s'\"\)\]]+\.(?:html?|m?js|css)(?:\b|[?#])", re.I)),
    ("web-only engine bridge", re.compile(r"\b(?:HTTPRequest|HTTPClient|JavaScriptBridge|OS\.shell_open)\b")),
    ("project-local excluded originals", re.compile(r"\bres://(?:source_assets|raw_assets)/", re.I)),
    ("remote file scheme", re.compile(r"\b(?:file|javascript|data)://", re.I)),
    ("absolute Windows resource path", re.compile(r"(?<![A-Za-z0-9])[A-Za-z]:[\\/](?:Users|Workspace|Dev|Games|Projects)[\\/]", re.I)),
)
LITERAL_RESOURCE = re.compile(r"""(?:"|')(?P<path>res://[^"'\r\n]+)(?:"|')""")
ASSET_ENDINGS = {
    ".gd", ".tscn", ".tres", ".gdshader", ".png", ".jpg", ".jpeg",
    ".webp", ".svg", ".mp3", ".ogg", ".wav", ".ttf", ".otf", ".json",
    ".cfg", ".shader", ".theme", ".material", ".res", ".import",
}


def runtime_files(root: Path) -> list[Path]:
    """Only source read by Godot, never docs, scripts, Godot-generated HTML."""
    paths = [p for p in root.iterdir() if p.is_file() and p.suffix in SUFFIXES]
    if (root / "project.godot").is_file():
        paths.append(root / "project.godot")
    for dirname in RUNTIME_DIRS:
        path = root / dirname
        if path.exists():
            paths.extend(p for p in path.rglob("*") if p.is_file() and p.suffix in SUFFIXES)
    return sorted(set(paths))


def inspect(root: Path) -> tuple[list[str], int, int, int]:
    errors: list[str] = []
    static_count = 0
    dynamic_count = 0
    checked = runtime_files(root)
    for path in checked:
        relative = path.relative_to(root).as_posix()
        try:
            source = path.read_text(encoding="utf-8")
        except UnicodeError:
            errors.append(f"{relative}: not valid UTF-8")
            continue
        for lineno, line in enumerate(source.splitlines(), start=1):
            stripped = line.lstrip()
            if stripped.startswith(("#", "//", ";")):
                continue
            for label, rule in FORBIDDEN:
                if rule.search(line):
                    errors.append(f"{relative}:{lineno}: {label}: {line.strip()[:140]}")
            for match in LITERAL_RESOURCE.finditer(line):
                res = match.group("path")
                # Godot format strings, script concatenation and directory
                # prefixes aren't literal static file dependencies.
                if any(token in res for token in ("%s", "%d", "%02d", "{", "}", "*")):
                    dynamic_count += 1
                    continue
                # The literal must be an expected file suffix, not an
                # intentionally incomplete prefix such as "res://assets/".
                if Path(res).suffix.lower() not in ASSET_ENDINGS:
                    dynamic_count += 1
                    continue
                target = root / res.removeprefix("res://")
                if not target.is_file():
                    errors.append(f"{relative}:{lineno}: missing local resource: {res}")
                else:
                    static_count += 1
    return errors, len(checked), static_count, dynamic_count


def self_test() -> bool:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / "systems").mkdir()
        (root / "assets").mkdir()
        (root / "assets" / "portrait.png").write_bytes(b"test")
        (root / "project.godot").write_text('[application]\nconfig/name="Test"\n', encoding="utf-8")
        file = root / "systems" / "game.gd"
        file.write_text(
            '# https://github.com/gamja121/necromancer-dice-board is a historical reference\n'
            'const LOCAL = "res://assets/portrait.png"\n'
            'const TEMPLATE = "res://assets/%s.png"\n',
            encoding="utf-8",
        )
        errors, count, resolved, dynamic = inspect(root)
        if errors or count != 2 or resolved != 1 or dynamic != 1:
            print("SELF_TEST_FAIL baseline", errors, count, resolved, dynamic)
            return False
        bad = [
            'const BAD = "https://example.com/api"\n',
            'const BAD = "res://web/old-game.js"\n',
            'const BAD = "res://assets/index.html"\n',
            'const BAD = "res://source_assets/missing.png"\n',
            'const BAD = "../necromancer-dice-board/raw"\n',
            'var client = HTTPRequest.new()\n',
            'const BAD = "res://assets/absent.png"\n',
            'const BAD = "C:\\\\Users\\\\Tester\\\\game.png"\n',
        ]
        for index, sample in enumerate(bad):
            file.write_text(sample, encoding="utf-8")
            findings, _, _, _ = inspect(root)
            if not findings:
                print(f"SELF_TEST_FAIL fixture {index} was not rejected: {sample.strip()}")
                return False
        print(f"WEB_INDEPENDENCE_SELF_TEST: {len(bad) + 1} fixtures passed, 0 failed")
        return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return 0 if self_test() else 1
    root = args.root.resolve()
    errors, count, static_count, dynamic_count = inspect(root)
    for error in errors:
        print("WEB_INDEPENDENCE_FAIL:", error)
    if errors:
        print(f"WEB_INDEPENDENCE: {count} runtime files scanned, {len(errors)} failures")
        return 1
    print(
        f"WEB_INDEPENDENCE_PASS: {count} runtime files scanned, "
        f"{static_count} static resources resolved, "
        f"{dynamic_count} dynamic paths inspected separately by Godot runtime CI; "
        "0 forbidden web/source/URL links"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
