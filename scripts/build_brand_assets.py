#!/usr/bin/env python3
"""Build Pulse color assets, brand mark, and AppIcon from one brand contract."""

from __future__ import annotations

import argparse
from io import BytesIO
import json
import os
from pathlib import Path
import tempfile

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
TOKEN_PATH = ROOT / "design" / "brand-tokens.json"
MASK_PATH = ROOT / "design" / "app-icon-source" / "open-day-ring-mask.png"
ASSET_CATALOG = ROOT / "pulse" / "Assets.xcassets"
WATCH_ASSET_CATALOG = ROOT / "PulseWatchAssets" / "Assets.xcassets"
APP_ICON_OUTPUT = ASSET_CATALOG / "AppIcon.appiconset"
WATCH_APP_ICON_OUTPUT = WATCH_ASSET_CATALOG / "AppIcon.appiconset"
BRAND_MARK_OUTPUT = ASSET_CATALOG / "PulseMark.imageset"
APP_ICON_REVIEW_OUTPUT = ROOT / "design" / "app-icon-review.png"
SIZE = (1024, 1024)
REVIEW_SIZE = (1600, 1230)

COLOR_ASSETS = {
    "AccentColor": "tint",
    "PulseAction": "action",
    "PulseActionForeground": "actionForeground",
    "PulseActivityIslandFirefly": "activityIslandFirefly",
    "PulseActivityLockScreenFirefly": "activityLockScreenFirefly",
    "PulseActivityMark": "activityMark",
    "PulseBackground": "background",
    "PulseEditorialAccent": "editorialAccent",
    "PulseField": "field",
    "PulseGrass": "grass",
    "PulseGrassForeground": "grassForeground",
    "PulseInk": "ink",
    "PulseQuietBlue": "quietBlue",
    "PulseQuietCanvas": "quietCanvas",
    "PulseQuietChrome": "quietChrome",
    "PulseQuietChromeForeground": "quietChromeForeground",
    "PulseQuietDivider": "quietDivider",
    "PulseQuietGreen": "quietGreen",
    "PulseQuietGreenDeep": "quietGreenDeep",
    "PulseQuietGreenSoft": "quietGreenSoft",
    "PulseQuietInk": "quietInk",
    "PulseQuietMuted": "quietMuted",
    "PulseQuietOnGreen": "quietOnGreen",
    "PulseQuietPink": "quietPink",
    "PulseQuietSurface": "quietSurface",
    "PulseQuietYellow": "quietYellow",
    "PulseSecondary": "secondary",
    "PulseSeparator": "separator",
    "PulseShadow": "shadow",
    "PulseSurface": "surface",
    "PulseSunlitCanvas": "sunlitCanvas",
    "PulseSunlitCanvasDeep": "sunlitCanvasDeep",
    "PulseSunlitSurface": "sunlitSurface",
    "PulseSunlitInk": "sunlitInk",
    "PulseSunlitMuted": "sunlitMuted",
    "PulseSunlitDivider": "sunlitDivider",
    "PulseSunlitAccent": "sunlitAccent",
    "PulseSunlitAccentSoft": "sunlitAccentSoft",
    "PulseSunlitMap": "sunlitMap",
    "PulseSunlitMapDeep": "sunlitMapDeep",
    "PulseSunlitChrome": "sunlitChrome",
    "PulseSunlitChromeForeground": "sunlitChromeForeground",
    "PulseSunlitOnAccent": "sunlitOnAccent",
    "PulseWidgetPaper": "widgetPaper",
    "PulseWidgetSkyGlow": "widgetSkyGlow",
    "PulseWidgetWater": "widgetWater",
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


def paste_rounded_preview(
    canvas: Image.Image,
    source: Image.Image,
    origin: tuple[int, int],
    size: int,
    *,
    resample: Image.Resampling = Image.Resampling.LANCZOS,
) -> None:
    preview = source.resize((size, size), resample=resample)
    corner_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(corner_mask).rounded_rectangle(
        (0, 0, size - 1, size - 1),
        radius=max(1, round(size * 0.22)),
        fill=255,
    )
    canvas.paste(preview, origin, corner_mask)


def build_icon_review(
    tokens: dict[str, object],
    mask: Image.Image,
    default_icon: Image.Image,
    dark_icon: Image.Image,
) -> Image.Image:
    review = tokens["review"]
    icon = tokens["icon"]
    expected_review_roles = {"canvas", "ink", "secondary", "tintedPreviewBackground"}
    if set(review) != expected_review_roles:
        missing = sorted(expected_review_roles - set(review))
        extra = sorted(set(review) - expected_review_roles)
        raise ValueError(f"Invalid review roles; missing={missing}, extra={extra}")

    canvas_color = parse_hex(review["canvas"])
    ink_color = parse_hex(review["ink"])
    secondary_color = parse_hex(review["secondary"])
    tinted_background_color = parse_hex(review["tintedPreviewBackground"])
    canvas = Image.new("RGB", REVIEW_SIZE, canvas_color)
    draw = ImageDraw.Draw(canvas)

    dark_background = Image.new("RGB", SIZE, parse_hex(icon["darkPreviewBackground"]))
    dark_background.paste(dark_icon, (0, 0), dark_icon.getchannel("A"))
    tinted_background = Image.new("RGB", SIZE, tinted_background_color)
    tinted_mark = Image.new("RGB", SIZE, ink_color)
    tinted_preview = Image.composite(tinted_mark, tinted_background, mask)

    top_size = 320
    top_y = 92
    top_origins = ((96, top_y), (640, top_y), (1184, top_y))
    top_sources = (default_icon, dark_background, tinted_preview)
    top_bars = (
        parse_hex(icon["defaultBackground"]),
        parse_hex(icon["darkMark"]),
        tinted_background_color,
    )
    for origin, source, bar_color in zip(top_origins, top_sources, top_bars, strict=True):
        paste_rounded_preview(canvas, source, origin, top_size)
        draw.rectangle(
            (origin[0], top_y + top_size + 32, origin[0] + top_size, top_y + top_size + 48),
            fill=bar_color,
        )

    draw.rectangle((72, 530, REVIEW_SIZE[0] - 72, 533), fill=secondary_color)

    baseline_y = 790
    size_specs = ((180, 112), (60, 526), (40, 790), (29, 1038))
    for icon_size, x in size_specs:
        paste_rounded_preview(
            canvas,
            default_icon,
            (x, baseline_y - icon_size),
            icon_size,
        )

    draw.rectangle((72, 842, REVIEW_SIZE[0] - 72, 845), fill=secondary_color)

    enlarged_size = 240
    enlarged_y = 918
    paste_rounded_preview(canvas, default_icon, (112, enlarged_y), enlarged_size)
    for source_size, x in ((60, 498), (40, 790), (29, 1082)):
        reduced = default_icon.resize(
            (source_size, source_size),
            resample=Image.Resampling.LANCZOS,
        )
        paste_rounded_preview(
            canvas,
            reduced,
            (x, enlarged_y),
            enlarged_size,
            resample=Image.Resampling.NEAREST,
        )

    return canvas


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
        asset = color_asset(
            tokens["light"][role],
            tokens["dark"][role],
        )
        outputs[ASSET_CATALOG / f"{asset_name}.colorset" / "Contents.json"] = asset
        outputs[WATCH_ASSET_CATALOG / f"{asset_name}.colorset" / "Contents.json"] = asset

    icon = tokens["icon"]
    expected_icon_roles = {
        "darkMark",
        "defaultBackground",
        "defaultMark",
        "darkPreviewBackground",
    }
    if set(icon) != expected_icon_roles:
        missing = sorted(expected_icon_roles - set(icon))
        extra = sorted(set(icon) - expected_icon_roles)
        raise ValueError(f"Invalid icon roles; missing={missing}, extra={extra}")
    default_background = Image.new("RGB", SIZE, parse_hex(icon["defaultBackground"]))
    default_mark = Image.new("RGB", SIZE, parse_hex(icon["defaultMark"]))
    default_icon = Image.composite(default_mark, default_background, mask)
    outputs[APP_ICON_OUTPUT / "AppIcon-Any.png"] = png_bytes(default_icon)
    outputs[WATCH_APP_ICON_OUTPUT / "AppIcon.png"] = png_bytes(default_icon)
    outputs[WATCH_APP_ICON_OUTPUT / "Contents.json"] = json_bytes(
        {
            "images": [
                {
                    "filename": "AppIcon.png",
                    "idiom": "universal",
                    "platform": "watchos",
                    "size": "1024x1024",
                }
            ],
            "info": {"author": "xcode", "version": 1},
        }
    )
    outputs[WATCH_ASSET_CATALOG / "Contents.json"] = json_bytes(
        {"info": {"author": "xcode", "version": 1}}
    )

    dark_mark = Image.new("RGBA", SIZE, (*parse_hex(icon["darkMark"]), 255))
    dark_mark.putalpha(mask)
    outputs[APP_ICON_OUTPUT / "AppIcon-Dark.png"] = png_bytes(dark_mark)
    outputs[APP_ICON_OUTPUT / "AppIcon-Tinted.png"] = png_bytes(mask)
    outputs[APP_ICON_REVIEW_OUTPUT] = png_bytes(
        build_icon_review(tokens, mask, default_icon, dark_mark)
    )

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

    updated_paths = []
    for path, data in outputs.items():
        if output_matches(path, data):
            continue
        write_atomically(path, data)
        updated_paths.append(path)
    print(
        f"Updated {len(updated_paths)} of {len(outputs)} brand assets "
        f"from {TOKEN_PATH.relative_to(ROOT)}"
    )


if __name__ == "__main__":
    main()
