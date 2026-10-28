#!/usr/bin/env python3
"""Build Pulse color assets, brand mark, and AppIcon from one brand contract."""

from __future__ import annotations

import argparse
from io import BytesIO
import json
import os
from pathlib import Path
import random
import shutil
import tempfile

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
TOKEN_PATH = ROOT / "design" / "brand-tokens.json"
FONT_PATH = ROOT / "pulse" / "Resources" / "Fonts" / "NotoSerifSC-Variable.ttf"
GLYPH_SOURCE_PATH = ROOT / "design" / "app-icon-source" / "seal-glyph.png"
ASSET_CATALOG = ROOT / "pulse" / "Assets.xcassets"
WATCH_ASSET_CATALOG = ROOT / "PulseWatchAssets" / "Assets.xcassets"
APP_ICON_OUTPUT = ASSET_CATALOG / "AppIcon.appiconset"
WATCH_APP_ICON_OUTPUT = WATCH_ASSET_CATALOG / "AppIcon.appiconset"
BRAND_MARK_OUTPUT = ASSET_CATALOG / "PulseMark.imageset"
APP_ICON_REVIEW_OUTPUT = ROOT / "design" / "app-icon-review.png"
SIZE = (1024, 1024)
REVIEW_SIZE = (1600, 1230)
SUPERSAMPLE = 2
GLYPH_SOURCE_SIDE = 2048
SEAL_GLYPH = "印"
ICON_SEAL_FRACTION = 0.62
ICON_SEAL_ROTATION = -3.0
MARK_SEAL_FRACTION = 0.94

COLOR_ASSETS = {
    "AccentColor": "tint",
    "PulseVermilionPaper": "vermilionPaper",
    "PulseVermilionPaperRaised": "vermilionPaperRaised",
    "PulseVermilionInk": "vermilionInk",
    "PulseVermilionMuted": "vermilionMuted",
    "PulseVermilionRule": "vermilionRule",
    "PulseVermilionSeal": "vermilionSeal",
    "PulseVermilionOnSeal": "vermilionOnSeal",
    "PulseVermilionSealWash": "vermilionSealWash",
    "PulseQuietPaper": "quietPaper",
    "PulseQuietPaperRaised": "quietPaperRaised",
    "PulseQuietInk": "quietInk",
    "PulseQuietMuted": "quietMuted",
    "PulseQuietRule": "quietRule",
    "PulseQuietSeal": "quietSeal",
    "PulseQuietOnSeal": "quietOnSeal",
    "PulseQuietSealWash": "quietSealWash",
    "PulseSunlitPaper": "sunlitPaper",
    "PulseSunlitPaperRaised": "sunlitPaperRaised",
    "PulseSunlitInk": "sunlitInk",
    "PulseSunlitMuted": "sunlitMuted",
    "PulseSunlitRule": "sunlitRule",
    "PulseSunlitSeal": "sunlitSeal",
    "PulseSunlitOnSeal": "sunlitOnSeal",
    "PulseSunlitSealWash": "sunlitSealWash",
    "PulseActivityIslandSeal": "activityIslandSeal",
    "PulseActivityLockScreenSeal": "activityLockScreenSeal",
}

WATCH_COLOR_ASSETS = {
    "AccentColor": "seal",
    "PulseWatchPaper": "paper",
    "PulseWatchPaperDeep": "paperDeep",
    "PulseWatchWashBack": "washBack",
    "PulseWatchWashMiddle": "washMiddle",
    "PulseWatchWashFront": "washFront",
    "PulseWatchInk": "ink",
    "PulseWatchMuted": "muted",
    "PulseWatchSeal": "seal",
}

WATCH_PREVIEW_COLOR_ASSETS = {
    "PulseWatchPreviewPaper": "paper",
    "PulseWatchPreviewPaperDeep": "paperDeep",
    "PulseWatchPreviewWashBack": "washBack",
    "PulseWatchPreviewWashMiddle": "washMiddle",
    "PulseWatchPreviewWashFront": "washFront",
    "PulseWatchPreviewInk": "ink",
    "PulseWatchPreviewMuted": "muted",
    "PulseWatchPreviewSeal": "seal",
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


def solid_color_asset(value: str) -> bytes:
    return json_bytes(
        {
            "colors": [
                {
                    "color": {"color-space": "srgb", "components": color_components(value)},
                    "idiom": "universal",
                }
            ],
            "info": {"author": "xcode", "version": 1},
        }
    )


def render_glyph_source() -> Image.Image:
    """Carve the brand glyph once from the bundled font.

    The committed PNG, not the font rasterizer, is what icon builds read, so
    `--check` stays byte-stable across Pillow and FreeType versions.
    """
    side = GLYPH_SOURCE_SIDE
    glyph = Image.new("L", (side, side), 0)
    draw = ImageDraw.Draw(glyph)
    font = ImageFont.truetype(str(FONT_PATH), size=round(side * 0.80))
    font.set_variation_by_name("Black")
    left, top, right, bottom = draw.textbbox((0, 0), SEAL_GLYPH, font=font)
    width, height = right - left, bottom - top
    scale = min(side * 0.74 / width, side * 0.76 / height)
    if scale < 1:
        font = ImageFont.truetype(str(FONT_PATH), size=round(side * 0.80 * scale))
        font.set_variation_by_name("Black")
        left, top, right, bottom = draw.textbbox((0, 0), SEAL_GLYPH, font=font)
        width, height = right - left, bottom - top
    origin_x = (side - width) / 2 - left
    origin_y = (side - height) / 2 - top
    draw.text((origin_x, origin_y), SEAL_GLYPH, font=font, fill=255)
    return glyph


def load_glyph_source() -> Image.Image:
    glyph = Image.open(GLYPH_SOURCE_PATH)
    expected = (GLYPH_SOURCE_SIDE, GLYPH_SOURCE_SIDE)
    if glyph.mode != "L" or glyph.size != expected:
        raise ValueError(f"Expected a {expected} grayscale glyph, got {glyph.mode} {glyph.size}")
    return glyph


def seal_impression_mask(
    glyph: Image.Image,
    *,
    canvas_side: int,
    seal_fraction: float,
    rotation: float,
    texture: float,
    seed: int,
) -> Image.Image:
    """One square seal impression as an L mask: 255 is ink; paper and the carved glyph are 0."""
    side = canvas_side * SUPERSAMPLE
    seal = round(side * seal_fraction)
    origin = (side - seal) // 2
    mask = Image.new("L", (side, side), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (origin, origin, origin + seal - 1, origin + seal - 1),
        radius=round(seal * 0.075),
        fill=255,
    )
    carved = glyph.resize((seal, seal), resample=Image.Resampling.LANCZOS)
    mask.paste(0, (origin, origin), carved)

    if texture > 0:
        rng = random.Random(seed)

        def uniform(low: float, high: float) -> float:
            return low + (high - low) * rng.random()

        erosion = Image.new("L", (side, side), 0)
        erosion_draw = ImageDraw.Draw(erosion)
        for _ in range(round(150 * texture)):
            edge = int(rng.random() * 4) % 4
            along = origin + rng.random() * seal
            radius = seal * uniform(0.003, 0.010)
            bite = radius * uniform(0.25, 0.75)
            if edge == 0:
                center = (along, origin + bite - radius)
            elif edge == 1:
                center = (origin + seal - bite + radius, along)
            elif edge == 2:
                center = (along, origin + seal - bite + radius)
            else:
                center = (origin + bite - radius, along)
            erosion_draw.ellipse(
                (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius),
                fill=255,
            )
        for _ in range(round(700 * texture)):
            center = (origin + rng.random() * seal, origin + rng.random() * seal)
            radius = seal * uniform(0.0012, 0.0045)
            erosion_draw.ellipse(
                (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius),
                fill=round(uniform(70, 230)),
            )
        erosion = erosion.filter(ImageFilter.GaussianBlur(radius=seal * 0.0012))

        wash = Image.new("L", (side, side), 0)
        wash_draw = ImageDraw.Draw(wash)
        for _ in range(7):
            center = (origin + rng.random() * seal, origin + rng.random() * seal)
            radius = seal * uniform(0.10, 0.26)
            wash_draw.ellipse(
                (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius),
                fill=round(uniform(16, 34) * texture),
            )
        wash = wash.filter(ImageFilter.GaussianBlur(radius=seal * 0.07))
        mask = ImageChops.subtract(ImageChops.subtract(mask, erosion), wash)

    if rotation:
        mask = mask.rotate(rotation, resample=Image.Resampling.BICUBIC, fillcolor=0)
    return mask.resize((canvas_side, canvas_side), resample=Image.Resampling.LANCZOS)


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
    impression: Image.Image,
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
    tinted_mark = Image.new("RGB", SIZE, (255, 255, 255))
    tinted_preview = Image.composite(tinted_mark, tinted_background, impression)

    top_size = 320
    top_y = 92
    top_origins = ((96, top_y), (640, top_y), (1184, top_y))
    top_sources = (default_icon, dark_background, tinted_preview)
    top_bars = (
        parse_hex(icon["seal"]),
        parse_hex(icon["darkSeal"]),
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

    draw.rectangle((72, 842, REVIEW_SIZE[0] - 72, 845), fill=ink_color)

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
    watch_roles = set(tokens["watch"])
    expected_watch_roles = set(WATCH_COLOR_ASSETS.values()) | set(WATCH_PREVIEW_COLOR_ASSETS.values())
    if watch_roles != expected_watch_roles:
        missing = sorted(expected_watch_roles - watch_roles)
        extra = sorted(watch_roles - expected_watch_roles)
        raise ValueError(f"Invalid watch roles; missing={missing}, extra={extra}")

    outputs: dict[Path, bytes] = {}
    for asset_name, role in COLOR_ASSETS.items():
        asset = color_asset(
            tokens["light"][role],
            tokens["dark"][role],
        )
        outputs[ASSET_CATALOG / f"{asset_name}.colorset" / "Contents.json"] = asset
    for asset_name, role in WATCH_COLOR_ASSETS.items():
        outputs[WATCH_ASSET_CATALOG / f"{asset_name}.colorset" / "Contents.json"] = (
            solid_color_asset(tokens["watch"][role])
        )
    for asset_name, role in WATCH_PREVIEW_COLOR_ASSETS.items():
        outputs[ASSET_CATALOG / f"{asset_name}.colorset" / "Contents.json"] = solid_color_asset(
            tokens["watch"][role]
        )

    icon = tokens["icon"]
    expected_icon_roles = {"paper", "seal", "darkSeal", "darkPreviewBackground"}
    if set(icon) != expected_icon_roles:
        missing = sorted(expected_icon_roles - set(icon))
        extra = sorted(set(icon) - expected_icon_roles)
        raise ValueError(f"Invalid icon roles; missing={missing}, extra={extra}")

    glyph = load_glyph_source()
    impression = seal_impression_mask(
        glyph,
        canvas_side=SIZE[0],
        seal_fraction=ICON_SEAL_FRACTION,
        rotation=ICON_SEAL_ROTATION,
        texture=1.0,
        seed=1015,
    )
    paper = Image.new("RGB", SIZE, parse_hex(icon["paper"]))
    seal = Image.new("RGB", SIZE, parse_hex(icon["seal"]))
    default_icon = Image.composite(seal, paper, impression)
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

    dark_icon = Image.new("RGBA", SIZE, (*parse_hex(icon["darkSeal"]), 255))
    dark_icon.putalpha(impression)
    outputs[APP_ICON_OUTPUT / "AppIcon-Dark.png"] = png_bytes(dark_icon)
    outputs[APP_ICON_OUTPUT / "AppIcon-Tinted.png"] = png_bytes(impression)
    outputs[APP_ICON_REVIEW_OUTPUT] = png_bytes(
        build_icon_review(tokens, impression, default_icon, dark_icon)
    )

    mark = seal_impression_mask(
        glyph,
        canvas_side=SIZE[0],
        seal_fraction=MARK_SEAL_FRACTION,
        rotation=0,
        texture=0.6,
        seed=27,
    )
    runtime_mark = Image.new("RGBA", SIZE, (255, 255, 255, 255))
    runtime_mark.putalpha(mark)
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


def unexpected_color_directories(outputs: dict[Path, bytes]) -> list[Path]:
    """Every color set in either catalog is generated, so any extra one is stale."""
    unexpected: list[Path] = []
    for catalog in (ASSET_CATALOG, WATCH_ASSET_CATALOG):
        expected = {
            path.parent
            for path in outputs
            if path.parent.parent == catalog and path.parent.suffix == ".colorset"
        }
        unexpected.extend(sorted(set(catalog.glob("*.colorset")) - expected))
    return unexpected


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail when committed generated assets differ from the brand contract.",
    )
    parser.add_argument(
        "--refresh-glyph",
        action="store_true",
        help="Re-carve design/app-icon-source/seal-glyph.png from the bundled font.",
    )
    arguments = parser.parse_args()
    if arguments.refresh_glyph:
        write_atomically(GLYPH_SOURCE_PATH, png_bytes(render_glyph_source()))
        print(f"Carved {GLYPH_SOURCE_PATH.relative_to(ROOT)}")
    outputs = build_outputs()

    drifted = [path for path, expected in outputs.items() if not output_matches(path, expected)]
    unexpected_colors = unexpected_color_directories(outputs)
    if arguments.check:
        if drifted or unexpected_colors:
            relative = ", ".join(
                str(path.relative_to(ROOT))
                for path in [*drifted, *unexpected_colors]
            )
            raise SystemExit(f"Generated brand assets are stale: {relative}")
        print(f"Verified {len(outputs)} generated brand assets")
        return

    updated_paths = []
    for directory in unexpected_colors:
        shutil.rmtree(directory)
        updated_paths.append(directory)
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
