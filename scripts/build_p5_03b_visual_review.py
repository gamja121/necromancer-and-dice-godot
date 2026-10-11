#!/usr/bin/env python3
"""P5-03B-1: exact-origin visual review kit for four Godot image changes.

Produces comparison previews and a machine-readable provenance manifest.
This is NOT an aesthetic, on-device, or user approval gate. Never overwrite
the original Godot source, archive, or historical audited TSV.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

import audit_p5_03_parity as base_audit

FROZEN_COMMIT = "e13d5149fcecc802e5d626f3bef6e5daecd3d66c"
SPEC = (
    ("fortune-teller", "art/v2-style/map-test/events/fortune-teller.jpg",
     "assets/map/events/fortune-teller.jpg"),
    ("home-interior", "art/v2-style/map-test/events/home-interior.jpg",
     "assets/map/events/home-interior.jpg"),
    ("knight-commander", "art/v2-style/event-portraits/knight-commander-upperbody-hd.webp",
     "assets/map/events/knight-commander-upperbody-hd.webp"),
    ("necromancer", "art/v2-style/event-portraits/necromancer-upperbody-hd.webp",
     "assets/map/events/necromancer-upperbody-hd.webp"),
)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            h.update(chunk)
    return h.hexdigest()


def git_blob(path: Path) -> str:
    return subprocess.check_output(
        ["git", "hash-object", "--", str(path)], text=True
    ).strip()


def display_font(size: int):
    try:
        return ImageFont.truetype("DejaVuSans.ttf", size)
    except OSError:
        return ImageFont.load_default()


def metadata(path: Path, *, frozen_reference: bool = False) -> dict:
    # Immutable legacy WebP snapshots can have a physically truncated RIFF
    # container. Preserve and report the actual signed bytes, never synthesize
    # pixels or 'repair' the header. Current Godot assets must fully decode.
    size = path.stat().st_size
    with path.open("rb") as stream:
        header = stream.read(12)
    riff_declared = None
    if len(header) == 12 and header[:4] == b"RIFF" and header[8:12] == b"WEBP":
        riff_declared = int.from_bytes(header[4:8], "little") + 8
        if riff_declared > size:
            if not frozen_reference:
                raise RuntimeError(f"current candidate has truncated WebP RIFF header: {path}")
            return {
                "format": "WEBP",
                "decode_status": "TRUNCATED_RIFF_CONTAINER",
                "file_bytes": size,
                "riff_declared_bytes": riff_declared,
                "missing_from_riff_bytes": riff_declared - size,
                "width": None, "height": None, "mode": None,
                "transparent_pixels": None, "translucent_pixels": None,
                "total_pixels": None,
                "file_sha256": sha256(path),
            }
    # Ensure Pillow really decodes the entire image, not merely its header.
    with Image.open(path) as image:
        image.load()
        corrected = ImageOps.exif_transpose(image)
        rgba = corrected.convert("RGBA")
        alpha_hist = rgba.getchannel("A").histogram()
        return {
            "format": image.format,
            "decode_status": "OK",
            "width": corrected.width,
            "height": corrected.height,
            "mode": corrected.mode,
            "transparent_pixels": alpha_hist[0],
            "translucent_pixels": sum(alpha_hist[1:255]),
            "total_pixels": corrected.width * corrected.height,
            "file_bytes": size,
            "riff_declared_bytes": riff_declared,
            "file_sha256": sha256(path),
        }

def checkerboard(width: int, height: int, step: int = 16) -> Image.Image:
    background = Image.new("RGBA", (width, height), "#eeeeee")
    d = ImageDraw.Draw(background)
    for y in range(0, height, step):
        for x in range(0, width, step):
            if ((x // step) + (y // step)) % 2:
                d.rectangle((x, y, min(width, x + step)-1,
                             min(height, y + step)-1), fill="#cdcdcd")
    return background


def paint_review(original: Path, current: Path, label: str,
                 before: dict, after: dict) -> Image.Image:
    # Fixed side-by-side viewport; preserve aspect ratio and transparency.
    card = Image.new("RGB", (1360, 554), "#f8f9fb")
    drawing = ImageDraw.Draw(card)
    title = display_font(23)
    body = display_font(16)
    drawing.text((26, 15), f"ASSET REVIEW (NOT APPROVED): {label}",
                 font=title, fill="#20232c")
    specs = ((original, before, 26, "FROZEN WEB — unchanged reference"),
             (current, after, 694, "GODOT — current candidate"))
    for path, stats, left, name in specs:
        drawing.text((left, 63), name, font=body, fill="#20232c")
        checker = checkerboard(630, 404)
        if stats["decode_status"] == "OK":
            with Image.open(path) as im:
                im.load()
                src = ImageOps.exif_transpose(im).convert("RGBA")
                src.thumbnail((620, 394), Image.Resampling.LANCZOS)
                x = (checker.width - src.width) // 2
                y = (checker.height - src.height) // 2
                checker.alpha_composite(src, (x, y))
            detail = (f"{stats['width']} x {stats['height']} | {stats['format']} "
                      f"| transparent {stats['transparent_pixels']:,} px")
        else:
            warn = ImageDraw.Draw(checker)
            warn.rectangle((15, 28, 613, 365), fill="#fff2ed", outline="#ba4238", width=3)
            warn.text((33, 90), "FROZEN ORIGINAL IS NOT DECODABLE", font=title, fill="#8f281e")
            warn.text((33, 138), f"Recorded file: {stats['file_bytes']:,} bytes", font=body, fill="#4a3331")
            warn.text((33, 165), f"WebP RIFF declares: {stats['riff_declared_bytes']:,} bytes",
                      font=body, fill="#4a3331")
            warn.text((33, 192), "No pixel comparison possible; do not invent pixels",
                      font=body, fill="#8f281e")
            detail = "ORIGINAL WEBP TRUNCATED | original pixels unavailable"
        card.paste(checker.convert("RGB"), (left, 93))
        drawing.text((left, 505), detail, font=body, fill="#22252d")
        drawing.text((left, 528), f"Git blob: {git_blob(path)[:22]}...",
                     font=body, fill="#535764")
    return card


def produce(root: Path, frozen: Path, out: Path) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    historic_assets = base_audit.read_rows(root / "docs/port_audit/asset_parity_audit.tsv")
    by_web = {row["web_path"]: row for row in historic_assets}
    records = []
    art = []
    for label, web_path, godot_path in SPEC:
        if web_path not in by_web:
            raise RuntimeError(f"asset reference row absent: {web_path}")
        entry = by_web[web_path]
        if entry["web_sha"] == "":
            raise RuntimeError(f"missing frozen web SHA: {web_path}")
        original = frozen / web_path
        current = root / godot_path
        if not original.is_file() or not current.is_file():
            raise RuntimeError(f"one or more actual image bytes are missing: {label}")
        original_blob = git_blob(original)
        current_blob = git_blob(current)
        if original_blob != entry["web_sha"]:
            raise RuntimeError(f"frozen web source SHA differs: {label}")
        if current_blob != base_audit.REVIEW_PENDING_BLOBS[godot_path]:
            raise RuntimeError(f"Godot candidate changed since original P5-03 audit: {label}")
        if original_blob == current_blob:
            raise RuntimeError(f"candidate is now identical; re-audit and remove obsolete review: {label}")
        before = metadata(original, frozen_reference=True)
        after = metadata(current)
        if after['decode_status'] != 'OK':
            raise RuntimeError(f'current Godot art does not decode: {godot_path}')
        damaged_expected = label in {'knight-commander', 'necromancer'}
        if (before['decode_status'] == 'TRUNCATED_RIFF_CONTAINER') != damaged_expected:
            raise RuntimeError(f'unexpected frozen source decode status {label}: {before["decode_status"]}')
        result = out / (label + "-comparison.png")
        view = paint_review(original, current, label, before, after)
        view.save(result, optimize=True)
        art.append(view)
        records.append({
            "id": label,
            "original_source": "gamja121/necromancer-dice-board",
            "frozen_commit": FROZEN_COMMIT,
            "web_path": web_path,
            "web_git_blob_sha1": original_blob,
            "web_metadata": before,
            "godot_path": godot_path,
            "godot_git_blob_sha1": current_blob,
            "godot_metadata": after,
            "comparison": result.name,
            "comparison_sha256": sha256(result),
            "original_decodable": before["decode_status"] == "OK",
            "visual_approval": "PENDING",
            "runtime_scene_acceptance": "NOT_CHECKED",
        })
    if len(records) != 4:
        raise RuntimeError("exactly four image-review records are required")
    if sum(item["original_decodable"] for item in records) != 2:
        raise RuntimeError("expected two valid original backgrounds and two broken legacy WebP portraits")
    # The summary is for comparison only; original files remain unmodified.
    summary = Image.new("RGB", (1360, len(art) * 554), "#f8f9fb")
    for i, preview in enumerate(art):
        summary.paste(preview, (0, i * 554))
    summary.save(out / "all-four-image-comparisons.png", optimize=True)
    manifest = {
        "source_commit": FROZEN_COMMIT,
        "scope": "P5-03B four changed images: provenance, dimensions, alpha and static previews",
        "does_not_prove": [
            "user approval of four visual changes",
            "correct placement inside live Godot runtime scenes",
            "Windows input/display/audio functionality",
            "PC-GitHub revision sync",
            "permission to delete frozen web sources",
        ],
        "images": records,
        "original_images_decodable": 2,
        "original_images_truncated": 2,
        "comparison_sheet": "all-four-image-comparisons.png",
        "comparison_sheet_sha256": sha256(out / "all-four-image-comparisons.png"),
    }
    (out / "review-manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print("P5_03B_PREVIEW_PASS: 4 pinned image pairs, 2 decoded original backgrounds, "
          "2 truncated original WebP portraits, 4 current Godot images decoded; "
          "4 review panels, 1 contact sheet; zero original edits")
    print("P5_03B_DELETION_BLOCKED: previews and decoded pixels are not PC/user acceptance")
    return manifest


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="p5-03b-self-") as temp:
        dest = Path(temp)
        left = dest / "original.png"
        right = dest / "candidate.png"
        Image.new("RGBA", (16, 12), (255, 0, 0, 0)).save(left)
        Image.new("RGBA", (32, 24), (0, 0, 255, 255)).save(right)
        a = metadata(left)
        b = metadata(right)
        if (a["transparent_pixels"], b["transparent_pixels"]) != (192, 0):
            raise RuntimeError("image alpha metadata test failed")
        view = paint_review(left, right, "fixture", a, b)
        if view.size != (1360, 554):
            raise RuntimeError("preview panel geometry changed unexpectedly")
        view.save(dest / "fixture.png")
        broken = dest / "truncated.webp"
        broken.write_bytes(b"RIFF" + (1000).to_bytes(4, "little") + b"WEBP" + b"INCOMPLETE")
        broken_meta = metadata(broken, frozen_reference=True)
        if broken_meta["decode_status"] != "TRUNCATED_RIFF_CONTAINER" or broken_meta["riff_declared_bytes"] != 1008:
            raise RuntimeError("truncated RIFF detection fixture failed")
        damaged_panel = paint_review(broken, right, "damaged fixture", broken_meta, b)
        damaged_panel.save(dest / "damaged.png")
        with Image.open(dest / "fixture.png") as test:
            test.verify()
        if git_blob(left) == git_blob(right):
            raise RuntimeError("self-test changed images must not be blob-identical")
    print("P5_03B_SELF_TEST_PASS: transparent/opaque, dimensions, truncated original detection, current decode")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--frozen-root", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if not args.frozen_root or not args.output:
        parser.error("--frozen-root and --output required outside --self-test")
    produce(args.root.resolve(), args.frozen_root.resolve(), args.output.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
