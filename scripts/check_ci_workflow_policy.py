#!/usr/bin/env python3
"""Dependency-free guard for Godot GitHub Actions refactoring.

This is a structural safety check, not an implementation of GitHub's YAML schema.
The companion Ruby Psych parser checks full YAML syntax.
"""
from collections import defaultdict
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
WF = ROOT / ".github" / "workflows"
GUARDED = (
    "ui-location-layout-stage5s", "story-state-regression",
    "windows-native-godot-validation", "p4-natural-full-story",
    "p4-natural-commander-hunter", "p4-natural-home-lap",
    "map-one-notch-gear", "patrol-six-slot-selection",
    "game-over-shatter", "graveyard-extraction-exit",
    "hill-forward-destination", "rest-tile-unlock",
    "shared-die-safety", "battle-formation-order",
    "battle-entry-summon", "godot-web-independence",
    "contamination-ten-slot-art",
)


def verify():
    paths = sorted(WF.glob("*.yml")) + sorted(WF.glob("*.yaml"))
    assert len(paths) >= len(GUARDED), "Missing workflow files"
    failed = []
    for name in GUARDED:
        path = WF / (name + ".yml")
        if not path.is_file():
            failed.append("Missing workflow: " + name)
            continue
        content = path.read_text(encoding="utf-8")
        for expectation in (
            "concurrency:\n",
            "github.workflow",
            "github.event_name",
            "github.event.pull_request.number || github.ref",
            "cancel-in-progress:",
            "github.event_name != 'workflow_dispatch'",
            "\njobs:\n",
        ):
            if expectation not in content:
                failed.append(f"{name}: missing {expectation!r}")
    location = (WF / "ui-location-layout-stage5s.yml").read_text(encoding="utf-8")
    header = location.split("\njobs:\n", 1)[0]
    push = header.split("  push:\n", 1)[1].split("  workflow_dispatch:", 1)[0]
    if "    paths:\n" not in push or "map.gd" not in push or "ui-location-layout-stage5s.yml" not in push:
        failed.append("Stage5S push scope must be explicitly restricted to relevant UI sources")
    if "docs/**" in push or '"**/*.gd"' in push:
        failed.append("Stage5S must not run unconditionally for documentation/generic code")
    script_users = defaultdict(list)
    imported = 0
    for path in paths:
        content = path.read_text(encoding="utf-8")
        imported += content.count("--editor --quit")
        for name in set(re.findall(r"--script\s+(?:res://)?(?:scripts/)?([a-zA-Z0-9_./-]+\.gd)", content)):
            script_users[name].append(path.name)
    frequently_repeated = sorted(
        ((len(uses), name) for name, uses in script_users.items() if len(uses) > 1),
        reverse=True,
    )[:5]
    print(f"CI_WORKFLOW_AUDIT: {len(paths)} workflows, {len(GUARDED)} latest-commit guards, {imported} import command references")
    for count, name in frequently_repeated:
        print(f"REPEATED_TEST: {name} in {count} workflow files")
    if failed:
        for failure in failed:
            print("FAIL " + failure, file=sys.stderr)
        return 1
    print("CI_WORKFLOW_POLICY: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(verify())
