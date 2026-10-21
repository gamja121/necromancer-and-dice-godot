#!/usr/bin/env python3
"""Fail CI if retired standalone brand-card gameplay code is reintroduced.

Monster *brand effects* are intentionally untouched. Prior-save brand-card
migration is allowed ONLY in RunSession's read-only backup and MapState's
legacy chest/merchant restore. Historical docs and negative test fixtures
are not active gameplay code.
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def audited_files() -> list[str]:
    names = subprocess.check_output(
        ["git", "ls-files", "-z"], cwd=ROOT
    ).decode("utf-8").split("\0")
    return sorted(
        path for path in names
        if (path.startswith("systems/") and path.endswith(".gd"))
        or path in {"map.gd", "main.gd", "battlefield.gd", "title.gd"}
        or path.endswith((".tscn", ".tres"))
    )


def main() -> int:
    errors: list[str] = []
    files = audited_files()

    # The old card image is no longer a game resource. Monster *brand frames*
    # and their icons are still essential, so don't remove those.
    for path in ("assets/cards/brand-card.png", "assets/cards/brand-card.png.import"):
        if (ROOT / path).exists():
            errors.append(f"retired card art came back: {path}")

    for path in files:
        for lineno, line in enumerate((ROOT / path).read_text(encoding="utf-8").splitlines(), 1):
            context = f"{path}:{lineno}"
            # These legacy field names may only be read once, when creating
            # an external save backup; never serialize or access as game state.
            if re.search(r"\b(?:legacy_)?brand_cards\b", line):
                if not (path == "systems/run_session.gd"
                        and 'if not parsed.has("brand_cards") and not parsed.has("legacy_brand_cards"):' in line):
                    errors.append(f"{context} active/archive card collection: {line.strip()}")
            if re.search(r"\b(?:brand_card_id|brand_fan|brand_options|select_brand_card)\b", line):
                errors.append(f"{context} retired card selection UI: {line.strip()}")
            if re.search(r'brand-card\.png', line):
                errors.append(f"{context} obsolete standalone card image: {line.strip()}")
            if re.search(r'create_item\(\s*["\']brand["\']', line):
                errors.append(f"{context} standalone brand-card generation: {line.strip()}")
            # Literal item kind=brand is safe only in old-save migration,
            # never during regular rewards, inventory, merchant trades or UI.
            if re.search(r'["\']brand["\']', line) and (
                re.search(r'(?:kind|offer\.kind|reward\.kind|offer\.get\(["\']kind)', line)
                or '["dice","brand","unit"]' in line
            ):
                permitted_restore_read = (
                    path == "systems/map_state.gd"
                    and any(token in line for token in (
                        '["dice","brand","unit"]',
                        'saved_offers.any(func(offer): return str(offer.get("kind",""))=="brand")',
                        'if str(offer.get("kind",""))!="brand": continue',
                        'if prepared.get("kind","")=="brand":',
                    ))
                )
                if not permitted_restore_read:
                    errors.append(f"{context} retired item kind in game logic: {line.strip()}")

    snapshot = (ROOT / "systems/map_state.gd").read_text(encoding="utf-8")
    if '"legacy_brand_cards":' in snapshot or '"brand_cards":' in snapshot:
        errors.append("MapState still serializes standalone card data")
    run = (ROOT / "systems/run_session.gd").read_text(encoding="utf-8")
    for required in ("func backup_retired_brand_cards", 'if not reward.kind in ["unit","dice"]'):
        if required not in run:
            errors.append(f"missing old-save protection or reward guard: {required}")
    if len(files) < 90:
        errors.append(f"unexpectedly small runtime source scan ({len(files)})")

    for error in errors:
        print("FAIL retired-brand-card-guard: " + error)
    print(f"RETIRED_BRAND_CARD_GUARD: {len(files)} runtime/resources scanned, {len(errors)} failures")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
