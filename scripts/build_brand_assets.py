#!/usr/bin/env python3
"""Build Pulse color assets, brand mark, and AppIcon from one brand contract."""

from __future__ import annotations

import argparse
from io import BytesIO
import json
import os
from pathlib import Path
import tempfile

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
TOKEN_PATH = ROOT / "design" / "brand-tokens.json"
MASK_PATH = ROOT / "design" / "app-icon-source" / "open-day-ring-mask.png"
ASSET_CATALOG = ROOT / "pulse" / "Assets.xcassets"
APP_ICON_OUTPUT = ASSET_CATALOG / "AppIcon.appiconset"
BRAND_MARK_OUTPUT = ASSET_CATALOG / "PulseMark.imageset"
SIZE = (1024, 1024)

COLOR_ASSETS = {
    "AccentColor": "tint",
    "PulseAction": "action",
    "PulseActionForeground": "actionForeground",
    "PulseBackground": "background",
    "PulseField": "field",
    "PulseGrass": "grass",
    "PulseGrassForeground": "grassForeground",
    "PulseInk": "ink",
    "PulseNavigationGlyphSurface": "navigationGlyphSurface",
    "PulseSecondary": "secondary",
    "PulseSeparator": "separator",
    "PulseShadow": "shadow",
    "PulseSurface": "surface",
}


def parse_hex(value: str) -> tuple[int, int, int]:
    if len(value) != 7 or not value.startswith("#"):
        raise ValueError(f"Expected #RRGGBB color, got {value!r}")
    return tuple(int(value[index : index + 2], 16) for index in (1, 3, 5))


def color_components(value: str) -> dict[str, str]:
    red, green, blue = parse_hex(value)
    return {
        "alpha": "1.000",
        "blue": f"{blue / 255:.3f}",
        "green": f"{green / 255:.3f}",
        "red": f"{red / 255:.3f}",
    }


def json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=False) + "\n").encode()


def png_bytes(image: Image.Image) -> bytes:
    output = BytesIO()
    image.save(output, format="PNG", optimize=True)
    return output.getvalue()


def color_asset(light: str, dark: str) -> bytes:
    return json_bytes(
        {
            "colors": [
                {
                    "color": {"color-space": "srgb", "components": color_components(light)},
                    "idiom": "universal",
                },
                {
                    "appearances": [{"appearance": "luminosity", "value": "dark"}],
                    "color": {"color-space": "srgb", "components": color_components(dark)},
                    "idiom": "universal",
                },
            ],
            "info": {"author": "xcode", "version": 1},
        }
    )


def build_outputs() -> dict[Path, bytes]:
    tokens = json.loads(TOKEN_PATH.read_text())
    expected_roles = set(COLOR_ASSETS.values())
    for appearance in ("light", "dark"):
        roles = set(tokens[appearance])
        if roles != expected_roles:
            missing = sorted(expected_roles - roles)
            extra = sorted(roles - expected_roles)
            raise ValueError(f"Invalid {appearance} roles; missing={missing}, extra={extra}")

    mask = Image.open(MASK_PATH)
    if mask.mode != "L" or mask.size != SIZE:
        raise ValueError(f"Expected a {SIZE[0]}x{SIZE[1]} grayscale mask, got {mask.mode} {mask.size}")

    outputs: dict[Path, bytes] = {}
    for asset_name, role in COLOR_ASSETS.items():
        outputs[ASSET_CATALOG / f"{asset_name}.colorset" / "Contents.json"] = color_asset(
            tokens["light"][role],
            tokens["dark"][role],
        )

    icon = tokens["icon"]
    default_background = Image.new("RGB", SIZE, parse_hex(icon["defaultBackground"]))
    default_mark = Image.new("RGB", SIZE, parse_hex(icon["defaultMark"]))
    outputs[APP_ICON_OUTPUT / "AppIcon-Any.png"] = png_bytes(
        Image.composite(default_mark, default_background, mask)
    )

    dark_mark = Image.new("RGBA", SIZE, (*parse_hex(icon["darkMark"]), 255))
    dark_mark.putalpha(mask)
    outputs[APP_ICON_OUTPUT / "AppIcon-Dark.png"] = png_bytes(dark_mark)
    outputs[APP_ICON_OUTPUT / "AppIcon-Tinted.png"] = png_bytes(mask)

    runtime_mark = Image.new("RGBA", SIZE, (255, 255, 255, 255))
    runtime_mark.putalpha(mask)
    outputs[BRAND_MARK_OUTPUT / "PulseMark.png"] = png_bytes(runtime_mark)
    outputs[BRAND_MARK_OUTPUT / "Contents.json"] = json_bytes(
        {
            "images": [
                {"filename": "PulseMark.png", "idiom": "universal", "scale": "1x"},
                {"idiom": "universal", "scale": "2x"},
                {"idiom": "universal", "scale": "3x"},
            ],
            "info": {"author": "xcode", "version": 1},
            "properties": {"template-rendering-intent": "template"},
        }
    )
    return outputs


def write_atomically(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as handle:
        handle.write(data)
        temporary_path = Path(handle.name)
    os.replace(temporary_path, path)


def output_matches(path: Path, expected: bytes) -> bool:
    if not path.exists():
        return False
    if path.suffix.lower() != ".png":
        return path.read_bytes() == expected

    try:
        with Image.open(path) as actual_image, Image.open(BytesIO(expected)) as expected_image:
            actual_image.load()
            expected_image.load()
            return (
                actual_image.mode == expected_image.mode
                and actual_image.size == expected_image.size
                and actual_image.tobytes() == expected_image.tobytes()
            )
    except (OSError, ValueError):
        return False


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail when committed generated assets differ from the brand contract.",
    )
    arguments = parser.parse_args()
    outputs = build_outputs()

    drifted = [path for path, expected in outputs.items() if not output_matches(path, expected)]
    if arguments.check:
        if drifted:
            relative = ", ".join(str(path.relative_to(ROOT)) for path in drifted)
            raise SystemExit(f"Generated brand assets are stale: {relative}")
        print(f"Verified {len(outputs)} generated brand assets")
        return

    for path, data in outputs.items():
        write_atomically(path, data)
    print(f"Generated {len(outputs)} brand assets from {TOKEN_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
