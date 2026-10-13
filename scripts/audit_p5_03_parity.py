#!/usr/bin/env python3
"""P5-03A: reconcile current tracked Godot files against 159 web features
and the original 791-row asset inventory without rewriting historical audits.

This is a code/art *inventory* gate, not Windows visual acceptance or permission
to delete the historical web repository.
"""
from __future__ import annotations

import argparse
import collections
import csv
import io
import json
import re
import subprocess
import sys
from pathlib import Path

APPROVED_STATUS = {"✅ 완료", "🔵 의도적 변경"}
CLASSIFICATIONS = {"REQUIRED", "REQUIRED_RULE", "WEB_IMPL_REPLACE"}
HISTORIC_MISSING = {"MISSING_REQUIRED", "MISSING_WITH_UNPORTED_STORY"}
HISTORIC_DISCARD = {"DISCARD_DEV_ONLY", "DISCARD_WEB_ALT"}
HISTORIC_MAPPED = {"EXACT", "EXACT_RENAMED", "UPDATED", "FALLBACK", "REPLACED"}
# These blobs exist, but content changed. Recording a current SHA here is
# *not* artistic approval and must not silently set P5-03 or P5-04 to DONE.
REVIEW_PENDING_BLOBS = {
    "assets/map/events/home-interior.jpg": "2623363f6851b5f7f70ac755dd798b208af0a08d",
    "assets/map/events/knight-commander-upperbody-hd.webp": "7710370f7462cf12da98f9721b054500d5b43c4e",
    "assets/map/events/necromancer-upperbody-hd.webp": "c707c93a5ca3feeca9a51c7baa1fd2252ea58970",
}
# Owner requested the five location paintings be restored to their
# pre-2026-10-13 replacement versions (commit 585c2bd). These entries pin
# those exact historical Git blobs, not the discarded new paintings.
# Preserve the immutable 791-row source ledger, presentation frame and UI.
# Fortune-teller's immediately previous blob differs from its older web
# ledger entry; that specific prior runtime version is intentional.
OWNER_APPROVED_TILE_SCENE_ART = {
    "assets/map/events/village.jpg": ("517e7d2a5e77d8378f1d74f1e7fb5a4332ab4f99", 316884),
    "assets/map/events/graveyard.jpg": ("104d532e6e636a481af2686508e1893d5b210559", 323393),
    "assets/map/events/altar.jpg": ("8ac0a1cd4ba270326030163b4bbdc4a3476338d5", 252740),
    "assets/map/events/home.jpg": ("616260406a18488f0d7a7e4a0c5772df946717de", 954098),
    "assets/map/events/fortune-teller.jpg": ("effcf0425a5a3fb9d015b7046a9a9500132134e9", 984867),
}
# Stage 5H repaired corrupt source PNGs into decodeable *runtime* copies.
# The immutable 791-row historical ledger deliberately still records the old
# single-sprite fallback; it is NOT rewritten as if those pixels were exact.
# Hash-pin all four runtime variants, and require the original third blob to
# remain available. Replacement cloud 4 is still visually incomplete.
RUNTIME_CLOUD_BLOBS = {
    "assets/map/ui/map_cloud_transition.png": "c367076294ec20ea0aa6c4e1a31d315cd0e9de44",
    "assets/map/ui/map_cloud_transition_2.png": "23308e4ee4634acb28484b5e6de0d04a913f2f26",
    "assets/map/ui/map_cloud_transition_3.png": "d10dcadffda9a4758314b54fc830011c1b9348d3",
    "assets/map/ui/map_cloud_transition_4.png": "f6b504c7078c994ee529d4bdc3ed689c36de7890",
}
HISTORICAL_CLOUD_FALLBACK_SHA = "d10dcadffda9a4758314b54fc830011c1b9348d3"
REVIEW_ORIGINS = {
    "art/v2-style/event-portraits/knight-commander-upperbody-hd.webp":
        "assets/map/events/knight-commander-upperbody-hd.webp",
    "art/v2-style/event-portraits/necromancer-upperbody-hd.webp":
        "assets/map/events/necromancer-upperbody-hd.webp",
}
EXPECTED_INTENTIONAL = {"W005", "W151", "W202"}


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as inp:
        reader = csv.DictReader(inp, delimiter="\t")
        if not reader.fieldnames or len(set(reader.fieldnames)) != len(reader.fieldnames):
            raise ValueError(f"invalid audit header: {path}")
        rows = list(reader)
        if any(None in row for row in rows):
            raise ValueError(f"extra/malformed TSV columns: {path}")
        return rows


def tracked_tree(root: Path) -> dict[str, tuple[str, int]]:
    raw = subprocess.check_output(
        ["git", "-C", str(root), "ls-tree", "-r", "-l", "-z", "HEAD"]
    )
    files = {}
    for record in raw.split(b"\0"):
        if not record:
            continue
        prefix, name = record.split(b"\t", 1)
        # "100644 blob <sha> <size>\t<path>"
        mode, objtype, sha, size = prefix.decode("ascii").split()
        if objtype == "blob":
            files[name.decode("utf-8", errors="surrogateescape")] = (sha, int(size))
    return files


def inspect(root: Path, tracked: dict[str, tuple[str, int]]) -> dict:
    problems = []
    features = read_rows(root / "docs/port_audit/feature_parity_audit.tsv")
    masters = read_rows(root / "docs/port_audit/web_feature_master.tsv")
    assets = read_rows(root / "docs/port_audit/asset_parity_audit.tsv")
    count_status = collections.Counter()
    actual_ids = set()
    if len(features) != 159:
        problems.append(f"feature count {len(features)} != 159")
    for row in features:
        fid = row["id"]
        if fid in actual_ids or not re.fullmatch(r"W\d{3}", fid):
            problems.append(f"duplicate/malformed feature ID {fid}")
        actual_ids.add(fid)
        status = row["parity_status"]
        count_status[status] += 1
        if status not in APPROVED_STATUS:
            problems.append(f"{fid} unresolved feature: {status}")
        if not row["audit_note"].strip():
            problems.append(f"{fid} missing parity rationale")
        candidates = [p.strip() for p in row["godot_candidates"].split(";") if p.strip()]
        if not candidates:
            problems.append(f"{fid} has no Godot candidate")
        for candidate in candidates:
            if (candidate not in tracked and
                    not any(path.startswith(candidate + "/") for path in tracked)):
                problems.append(f"{fid} missing Godot candidate: {candidate}")
    master = {r["id"]: r for r in masters}
    required = {key: r for key, r in master.items() if r["classification"] in CLASSIFICATIONS}
    if len(masters) != len(master):
        problems.append("duplicate IDs in web_feature_master.tsv")
    if set(required) != actual_ids:
        problems.append(f"required web feature ID mismatch: "
                        f"missing={sorted(set(required)-actual_ids)}, "
                        f"extra={sorted(actual_ids-set(required))}")
    for row in features:
        web = master.get(row["id"])
        if web and web["classification"] != row["web_classification"]:
            problems.append(f"{row['id']} web feature classification changed")
    intentional = {r["id"] for r in features if r["parity_status"] == "🔵 의도적 변경"}
    if intentional != EXPECTED_INTENTIONAL:
        problems.append(f"unreviewed intentional change: {sorted(intentional)}")
    if count_status.get("✅ 완료", 0) != 156 or count_status.get("🔵 의도적 변경", 0) != 3:
        problems.append(f"unexpected feature totals: {dict(count_status)}")

    matched_sha_paths = collections.defaultdict(list)
    for path, (sha, size) in tracked.items():
        matched_sha_paths[sha].append(path)
    archive = []
    review = []
    missing = []
    baseline = collections.Counter()
    observed_review = set()
    observed_cloud_repair = set()
    if len(assets) != 791:
        problems.append(f"asset baseline rows {len(assets)} != 791")
    for row in assets:
        status = row["status"]
        baseline[status] += 1
        original = row["web_path"]
        expected_sha = row["web_sha"]
        godot_path = row["godot_path"]
        if status in HISTORIC_DISCARD:
            if godot_path:
                problems.append(f"discard status unexpectedly has Godot path: {original}")
            continue
        if status in HISTORIC_MAPPED:
            if not godot_path or godot_path not in tracked:
                missing.append((original, godot_path))
                problems.append(f"missing mapped asset: {original} -> {godot_path}")
                continue
            sha, size = tracked[godot_path]
            expected = row["godot_sha"]
            if sha != expected or size != int(row["godot_size"]):
                if godot_path in OWNER_APPROVED_TILE_SCENE_ART and (sha, size) == OWNER_APPROVED_TILE_SCENE_ART[godot_path]:
                    pass  # Owner-selected, hash-pinned previous artwork restored from Git history.
                elif godot_path in REVIEW_PENDING_BLOBS and sha == REVIEW_PENDING_BLOBS[godot_path]:
                    observed_review.add(godot_path)
                    review.append({"web_path": original, "godot_path": godot_path,
                                   "reference_sha": expected_sha, "current_sha": sha,
                                   "reason": "historical EXACT record differs; visual approval required"})
                elif (godot_path == "assets/map/ui/map_cloud_transition.png"
                      and expected == HISTORICAL_CLOUD_FALLBACK_SHA
                      and sha == RUNTIME_CLOUD_BLOBS[godot_path]
                      and tracked.get("assets/map/ui/map_cloud_transition_3.png", ("", 0))[0]
                          == HISTORICAL_CLOUD_FALLBACK_SHA):
                    # The old 1/2/3/4 mapping all pointed to a single copy
                    # of sprite 3. Stage 5H supplied four distinct source
                    # runtime sprites and repaired damaged PNG containers.
                    # This exception is hash-pinned and NEVER artistic approval.
                    observed_cloud_repair.add(godot_path)
                else:
                    problems.append(f"unexplained mapped asset drift {godot_path}: "
                                    f"ledger {expected}, current {sha}")
            if status in {"EXACT", "EXACT_RENAMED"} and expected_sha != expected:
                problems.append(f"invalid historical exact mapping {original}")
            continue
        if status in HISTORIC_MISSING:
            if godot_path:
                problems.append(f"historic missing record unexpectedly mapped: {original}")
            exact = sorted(p for p in matched_sha_paths.get(expected_sha, [])
                           if p.startswith("assets/"))
            if exact:
                # Record the *existing* relocated Godot blob, not a guessed name.
                archive.append({"web_path": original, "godot_path": exact[0],
                                "web_sha": expected_sha, "current_sha": expected_sha,
                                "classification": "NOW_EXACT"})
                continue
            replacement = REVIEW_ORIGINS.get(original)
            if replacement and replacement in tracked:
                sha, size = tracked[replacement]
                if sha != REVIEW_PENDING_BLOBS[replacement]:
                    problems.append(f"unreviewed altered portrait {replacement}: {sha}")
                else:
                    observed_review.add(replacement)
                    archive.append({"web_path": original, "godot_path": replacement,
                                    "web_sha": expected_sha, "current_sha": sha,
                                    "classification": "NOW_PRESENT_CHANGED_REVIEW"})
                    review.append({"web_path": original, "godot_path": replacement,
                                   "reference_sha": expected_sha, "current_sha": sha,
                                   "reason": "web portrait restored as modified asset; visual approval required"})
            else:
                missing.append((original, replacement))
                problems.append(f"old missing asset remains unavailable: {original}")
            continue
        problems.append(f"unexpected historical asset status: {status}")

    for path, pinned in OWNER_APPROVED_TILE_SCENE_ART.items():
        if tracked.get(path) != pinned:
            problems.append(f"previous tile painting drift {path}: "
                            f"expected {pinned}, found {tracked.get(path)}")
    if observed_review != set(REVIEW_PENDING_BLOBS):
        problems.append(f"missing or unexpected review-pending drift: "
                        f"{sorted(set(REVIEW_PENDING_BLOBS)-observed_review)}")
    if observed_cloud_repair != {"assets/map/ui/map_cloud_transition.png"}:
        problems.append("historical cloud fallback drift was not matched to the documented Stage 5H repair")
    for cloud_path, expected_sha in RUNTIME_CLOUD_BLOBS.items():
        actual_sha, actual_size = tracked.get(cloud_path, ("", 0))
        if actual_sha != expected_sha or actual_size <= 0:
            problems.append(f"unapproved runtime cloud image drift {cloud_path}: "
                            f"expected {expected_sha}, found {actual_sha}")
    if tracked.get("assets/map/ui/map_cloud_transition_3.png", ("", 0))[0] != HISTORICAL_CLOUD_FALLBACK_SHA:
        problems.append("original preserved cloud 3 fallback is missing")
    if len(archive) != 22:
        problems.append(f"historic missing resolution count {len(archive)} != 22")
    if sum(x["classification"] == "NOW_EXACT" for x in archive) != 20:
        problems.append("expected 20 exact original-blob relocated sources")
    if len(review) != len(REVIEW_PENDING_BLOBS):
        problems.append(f"expected {len(REVIEW_PENDING_BLOBS)} unapproved visual-change reviews, found {len(review)}")

    queue = read_rows(root / "docs/port_audit/migration_work_queue.tsv")
    work = {r["work_id"]: r for r in queue}
    mandatory = ("P3-05", "P4-01F", "P4-02E-B", "P4-04B", "P5-02B", "P5-04")
    for fid in mandatory:
        if fid not in work or work[fid]["status"] == "DONE":
            problems.append(f"unverified deletion blocker incorrectly marked DONE: {fid}")
    # Code-level scan can pass while P5-02 and P5-03 are still gated by PC/visual.
    result = {
        "feature_count": len(features),
        "feature_statuses": dict(count_status),
        "required_master_count": len(required),
        "asset_count": len(assets),
        "historical_asset_statuses": dict(baseline),
        "historical_missing_now_found": len(archive),
        "historical_missing_exact": sum(x["classification"] == "NOW_EXACT" for x in archive),
        "historical_missing_changed": sum(x["classification"] == "NOW_PRESENT_CHANGED_REVIEW" for x in archive),
        "mapped_assets_missing": len(missing),
        "candidate_paths_missing": sum("missing Godot candidate" in x for x in problems),
        "review_pending": review,
        "runtime_cloud_repairs_pending_visual_approval": [
            {"path": name, "tracked_sha": sha, "source_exact": name.endswith("_3.png")}
            for name, sha in RUNTIME_CLOUD_BLOBS.items()
        ],
        "historical_reconciliations": archive,
        "deletion_blockers": {name: work[name]["status"] for name in mandatory if name in work},
        "errors": problems,
    }
    return result


def self_test() -> bool:
    fixtures = [
        ("normal", {"assets/a.webp": ("a" * 40, 2)}, "a" * 40, True),
        ("different SHA", {"assets/a.webp": ("b" * 40, 2)}, "a" * 40, False),
        ("missing", {}, "a" * 40, False),
    ]
    for name, tree, sha, should_pass in fixtures:
        passed = any(p.startswith("assets/") for p, (digest, _) in tree.items()
                     if digest == sha)
        if passed != should_pass:
            print("P5_03_SELF_TEST_FAIL:", name)
            return False
    print("P5_03_SELF_TEST_PASS: 3 missing/changed/exact fixtures, 0 failures")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--json-output", type=Path)
    args = parser.parse_args()
    if args.self_test:
        return 0 if self_test() else 1
    root = args.root.resolve()
    result = inspect(root, tracked_tree(root))
    if args.json_output:
        args.json_output.write_text(json.dumps(result, ensure_ascii=False, indent=2)
                                   + "\n", encoding="utf-8")
    for item in result["review_pending"]:
        print(f"P5_03_REVIEW_PENDING: {item['godot_path']} "
              f"{item['reference_sha']} -> {item['current_sha']}")
    for item in result["runtime_cloud_repairs_pending_visual_approval"]:
        print(f"P5_03_CLOUD_SOURCE_REPAIR_NOT_APPROVED: {item['path']} "
              f"{item['tracked_sha']} exact_original={item['source_exact']}")
    for error in result["errors"]:
        print("P5_03_AUDIT_FAIL:", error)
    if result["errors"]:
        print(f"P5_03_AUDIT_FAIL: {len(result['errors'])} audit errors; "
              "never authorize deletion")
        return 1
    print(f"P5_03_CODE_AUDIT_PASS: {result['feature_count']} features, "
          f"{result['feature_statuses'].get('✅ 완료', 0)} ported, "
          f"{result['feature_statuses'].get('🔵 의도적 변경', 0)} intentional; "
          f"{result['asset_count']} historical assets, "
          f"{result['historical_missing_now_found']} former missing found "
          f"({result['historical_missing_exact']} exact / "
          f"{result['historical_missing_changed']} changed), "
          f"{len(result['review_pending'])} unapproved visual differences; "
          "0 missing tracked mappings")
    print("P5_03_DELETION_NOT_AUTHORIZED: PC visual, original backups, "
          "offsite copy, Pages relocation and owner approval outstanding")
    return 0


if __name__ == "__main__":
    sys.exit(main())
