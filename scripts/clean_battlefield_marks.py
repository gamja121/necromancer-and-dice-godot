#!/usr/bin/env python3
"""Remove only the small four-point Gemini marks from the three ORIGINAL
battlefield JPEGs. Never redraw, crop, resize, or recolor the compositions.

Source reference: 1280x575, verified against GitHub original images.
Run: python scripts/clean_battlefield_marks.py
"""
from pathlib import Path
import sys

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
BACKGROUNDS = ROOT / "assets" / "battle" / "backgrounds"
REFERENCE_WIDTH = 1280
REFERENCE_HEIGHT = 575
# Each existing painting has one white diamond watermark in the lower-right.
# Center in ORIGINAL pixel coordinates, and mask only the logo plus 2-3px edge.
MARKS = {
    "dark-forest.jpg": (1193, 475, 27, 29),
    "snow-forest.jpg": (1193, 509, 27, 29),
    "lava-forest.jpg": (1193, 535, 27, 29),
}

def clean(path: Path, spec: tuple[int, int, int, int]) -> None:
    original = cv2.imread(str(path), cv2.IMREAD_COLOR)
    if original is None:
        raise RuntimeError(f"Cannot read {path}")
    height, width = original.shape[:2]
    if (width, height) != (REFERENCE_WIDTH, REFERENCE_HEIGHT):
        raise RuntimeError(
            f"{path.name}: dimensions {width}x{height}, expected "
            f"{REFERENCE_WIDTH}x{REFERENCE_HEIGHT}; refuse unreviewed edit"
        )
    cx, cy, rx, ry = spec
    mask = np.zeros((height, width), dtype=np.uint8)
    cv2.ellipse(mask, (cx, cy), (rx, ry), 0, 0, 360, 255, -1)
    # The neighboring dirt/snow/ash is sampled at the rim of a small mask.
    # All architecture, framing trees, background, and battle floor outside
    # the localized logo region remain unchanged in composition and content.
    cleaned = cv2.inpaint(original, mask, 5, cv2.INPAINT_TELEA)
    if not cv2.imwrite(str(path), cleaned, [cv2.IMWRITE_JPEG_QUALITY, 96]):
        raise RuntimeError(f"Cannot save {path}")
    reloaded = cv2.imread(str(path), cv2.IMREAD_COLOR)
    if reloaded is None or reloaded.shape != original.shape:
        raise RuntimeError(f"Invalid output for {path}")
    outside_mask = mask == 0
    mean_difference = float(
        np.abs(reloaded.astype(np.int16) - original.astype(np.int16))
        [outside_mask].mean()
    )
    if mean_difference >= 7.0:
        raise RuntimeError(
            f"Unexpected edit beyond localized logo: "
            f"{path.name} outside-mask mean difference {mean_difference:.3f}"
        )
    print(
        f"{path.name}: {width}x{height}, centered removal at ({cx},{cy}), "
        f"ellipse {rx}x{ry}, outside-mask JPEG-only MAE {mean_difference:.3f}"
    )

def main() -> int:
    for name, spec in MARKS.items():
        clean(BACKGROUNDS / name, spec)
    return 0

if __name__ == "__main__":
    sys.exit(main())
