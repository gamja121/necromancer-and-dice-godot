#!/usr/bin/env python3
"""Regenerate the 12 original guardian-seed V2 battle frames.

Frozen source: gamja121/necromancer-dice-board
  reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c
  art/v2-style/animation-sheets/green-raw/guardian-seed-animation-sheet.jpg
  Git blob: 4d128a8a843ec4b56767be96f0d84facc1d92b37

Port of v2-seed-frames.js and v2-mantis-frames.js:
  crop each cell, magenta chroma key, calculate alpha > 8 bounding box,
  then draw trimmed sprite at horizontal center, bottom - 10, on 280x260.

Usage: python3 scripts/port_guardian_seed_frames.py /path/to/frozen-original.jpg
"""
import hashlib
import os
import sys
from pathlib import Path

from PIL import Image

SOURCE_GIT_BLOB = "4d128a8a843ec4b56767be96f0d84facc1d92b37"
SOURCE_SIZE = 85503
ROWS = {
    "attack": ([146, 338, 540, 806, 1020, 1260], 22, 252),
    "hit": ([146, 338, 548, 738], 270, 458),
    "death": ([140, 320, 540, 764, 1012], 498, 686),
}
DEST = Path(__file__).resolve().parents[1] / "assets/battle/frames/guardian-seed"


def git_blob_sha(data: bytes) -> str:
    payload = b"blob " + str(len(data)).encode() + b"\\0" + data
    return hashlib.sha1(payload).hexdigest()


def unmagenta(cell: Image.Image) -> Image.Image:
    # Faithful port of v2-mantis-frames.js keyMagenta() for the frozen sheet.
    rgba = cell.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            excess = min(red, blue) - green
            if excess <= 8:
                continue
            if excess >= 220:
                pixels[x, y] = (red, green, blue, 0)
                continue
            a = 1.0 - excess / 255.0
            pixels[x, y] = (
                min(255, max(0, round((red - excess) / a))),
                min(255, round(green / a)),
                min(255, max(0, round((blue - excess) / a))),
                min(255, round(alpha * a)),
            )
    return rgba


def build(source: Path) -> None:
    data = source.read_bytes()
    assert len(data) == SOURCE_SIZE, "Source JPEG byte count differs from frozen web"
    assert git_blob_sha(data) == SOURCE_GIT_BLOB, "Source JPEG SHA differs from frozen web"
    with Image.open(source) as image:
        assert image.size == (1280, 698), "Unexpected original seed sheet dimensions"
        DEST.mkdir(parents=True, exist_ok=True)
        for motion, (edges, top, bottom) in ROWS.items():
            for index, start in enumerate(edges[:-1], 1):
                stop = edges[index]
                crop = unmagenta(image.crop((start, top, stop, bottom)))
                alpha = crop.getchannel("A")
                # Web bounding box ignores alpha <= 8, not fully transparent only.
                threshold = alpha.point(lambda a: 255 if a > 8 else 0)
                bounds = threshold.getbbox()
                assert bounds is not None, f"Empty original {motion} frame {index}"
                left, high, right, low = bounds
                assert left > 0 and high > 0 and right < crop.width and low < crop.height, (
                    f"Crop touches source cell border: {motion} frame {index}"
                )
                sprite = crop.crop(bounds)
                assert sprite.width <= 280 and sprite.height <= 250
                output = Image.new("RGBA", (280, 260), (0, 0, 0, 0))
                output.alpha_composite(sprite, ((280 - sprite.width) // 2, 260 - 10 - sprite.height))
                filename = DEST / f"{motion}-{index:02d}.png"
                output.save(filename, optimize=True)
                assert filename.stat().st_size > 500, f"Empty output {filename}"
                print(f"W195_SEED_FRAME: {filename.relative_to(DEST.parents[3])} {sprite.size}")
    print("W195_SEED_GENERATION: 12 original web frames reconstructed")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Expected source JPEG path")
    build(Path(sys.argv[1]))
