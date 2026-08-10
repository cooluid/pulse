#!/usr/bin/env python3
"""Build every AppIcon appearance from the single approved monochrome mark."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MASK_PATH = ROOT / "design" / "app-icon-source" / "open-day-ring-mask.png"
PALETTE_PATH = ROOT / "design" / "app-icon-source" / "palette.json"
OUTPUT = ROOT / "pulse" / "Assets.xcassets" / "AppIcon.appiconset"
SIZE = (1024, 1024)


def hex_color(value: str) -> tuple[int, int, int]:
    if len(value) != 7 or not value.startswith("#"):
        raise ValueError(f"Expected #RRGGBB color, got {value!r}")
    return tuple(int(value[index : index + 2], 16) for index in (1, 3, 5))


def main() -> None:
    mask = Image.open(MASK_PATH)
    if mask.mode != "L" or mask.size != SIZE:
        raise ValueError(f"Expected a {SIZE[0]}x{SIZE[1]} grayscale mask, got {mask.mode} {mask.size}")

    palette = json.loads(PALETTE_PATH.read_text())
    light_background = Image.new("RGB", SIZE, hex_color(palette["default"]["background"]))
    light_mark = Image.new("RGB", SIZE, hex_color(palette["default"]["mark"]))
    Image.composite(light_mark, light_background, mask).save(OUTPUT / "AppIcon-Any.png", optimize=True)

    dark_mark = Image.new("RGBA", SIZE, (*hex_color(palette["dark"]["mark"]), 255))
    dark_mark.putalpha(mask)
    dark_mark.save(OUTPUT / "AppIcon-Dark.png", optimize=True)

    # Apple applies the user's selected tint to this grayscale luminance source.
    mask.save(OUTPUT / "AppIcon-Tinted.png", optimize=True)

    for filename in ("AppIcon-Any.png", "AppIcon-Dark.png", "AppIcon-Tinted.png"):
        image = Image.open(OUTPUT / filename)
        if image.size != SIZE:
            raise ValueError(f"Invalid size for {filename}: {image.size}")


if __name__ == "__main__":
    main()
