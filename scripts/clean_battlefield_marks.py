#!/usr/bin/env python3
"""Precisely remove three small 4-point lower-right source-watermarks.

Recreate each image from the actual reviewed MAIN ORIGINAL (never the
previously patched output). Preserve its exact 1280x575 hand-inked composition.
Only stamp a tiny patch of equivalent surrounding ground texture into the logo.
"""
from pathlib import Path
import subprocess
import sys

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL_COMMIT = "e492e57008493a1fa4e42f8499c3f6bfb7a7ed45"
WIDTH, HEIGHT = 1280, 575

# (x, y, ellipse half-width, half-height, source offset x, source offset y)
# White 4-ray marks near the bottom right, not the intended snowflakes/runes.
MARKS = {
    "dark-forest.jpg": (1182, 477, 28, 28, -80, 0),
    "snow-forest.jpg": (1183, 509, 30, 30, -103, -18),
    "lava-forest.jpg": (1193, 535, 32, 32, -67, 0),
}

def load_reviewed_original(rel_path: str) -> np.ndarray:
    data = subprocess.check_output(
        ["git", "show", f"{ORIGINAL_COMMIT}:{rel_path}"], cwd=ROOT
    )
    img = cv2.imdecode(np.frombuffer(data, dtype=np.uint8), cv2.IMREAD_COLOR)
    if img is None or img.shape[:2] != (HEIGHT, WIDTH):
        raise RuntimeError(f"Original missing or unexpected size: {rel_path}")
    return img

def clone_small_patch(original: np.ndarray, cfg: tuple[int, ...]) -> np.ndarray:
    cx, cy, rx, ry, dx, dy = cfg
    corrected = original.copy()
    # Composite a source patch from adjacent unmarked ground:
    # full-opacity within 80% of the ellipse, smoothly fade the outer 20%.
    # The rest of the source scene is pixel-identical until JPEG re-encoding.
    for y in range(max(0, cy - ry), min(HEIGHT, cy + ry + 1)):
        for x in range(max(0, cx - rx), min(WIDTH, cx + rx + 1)):
            d = ((x-cx)/rx)**2 + ((y-cy)/ry)**2
            if d >= 1.0:
                continue
            if x+dx < 0 or x+dx >= WIDTH or y+dy < 0 or y+dy >= HEIGHT:
                raise RuntimeError("Patch sampling escapes canvas")
            r = d ** .5
            a = 1.0 if r <= .80 else (1.0 - r) / .20
            corrected[y, x] = np.clip(
                original[y+dy, x+dx].astype(float)*a
                + original[y, x].astype(float)*(1.0-a),
                0, 255,
            ).astype(np.uint8)
    return corrected

def main() -> int:
    for name, cfg in MARKS.items():
        rel = f"assets/battle/backgrounds/{name}"
        original = load_reviewed_original(rel)
        new = clone_small_patch(original, cfg)
        out = ROOT / rel
        if not cv2.imwrite(str(out), new, [cv2.IMWRITE_JPEG_QUALITY, 97]):
            raise RuntimeError(f"Failed to write {rel}")
        roundtrip = cv2.imread(str(out), cv2.IMREAD_COLOR)
        if roundtrip is None or roundtrip.shape != original.shape:
            raise RuntimeError(f"Invalid output {rel}")
        x, y, rx, ry, _, _ = cfg
        # Audit: only ordinary JPEG re-encoding should change outside patch.
        ys, xs = np.ogrid[:HEIGHT, :WIDTH]
        outside = ((xs-x)/rx)**2+((ys-y)/ry)**2 >= 1.0
        mean_diff = np.abs(
            roundtrip.astype(np.int16)-original.astype(np.int16)
        )[outside].mean()
        if mean_diff > 6.0:
            raise RuntimeError(f"Outside-logo change too large: {name}, {mean_diff:.3f}")
        print(f"{name}: original {WIDTH}x{HEIGHT} retained; "
              f"logo patch at ({x},{y}), outside change {mean_diff:.3f}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
