#!/usr/bin/env python3
"""Build every AppIcon appearance from the single approved monochrome mark."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "pulse" / "Assets.xcassets"
MASK_PATH = ROOT / "design" / "app-icon-source" / "open-day-ring-mask.png"
OUTPUT = ASSETS / "AppIcon.appiconset"
SIZE = (1024, 1024)


def asset_color(name: str, *, dark: bool) -> tuple[int, int, int]:
    payload = json.loads((ASSETS / f"{name}.colorset" / "Contents.json").read_text())
    for entry in payload["colors"]:
        appearances = entry.get("appearances", [])
        is_dark = any(item.get("value") == "dark" for item in appearances)
        if is_dark != dark:
            continue
        components = entry["color"]["components"]
        return tuple(round(float(components[key]) * 255) for key in ("red", "green", "blue"))
    raise ValueError(f"Missing {'dark' if dark else 'light'} color for {name}")


def main() -> None:
    mask = Image.open(MASK_PATH)
    if mask.mode != "L" or mask.size != SIZE:
        raise ValueError(f"Expected a {SIZE[0]}x{SIZE[1]} grayscale mask, got {mask.mode} {mask.size}")

    light_background = Image.new("RGB", SIZE, asset_color("PulseBackground", dark=False))
    light_mark = Image.new("RGB", SIZE, asset_color("AccentColor", dark=False))
    Image.composite(light_mark, light_background, mask).save(OUTPUT / "AppIcon-Any.png", optimize=True)

    dark_mark = Image.new("RGBA", SIZE, (*asset_color("AccentColor", dark=True), 255))
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
