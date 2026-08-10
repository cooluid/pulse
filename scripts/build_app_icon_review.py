#!/usr/bin/env python3
"""Create a review sheet that preserves actual small-icon raster evidence."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "pulse" / "Assets.xcassets" / "AppIcon.appiconset"
OUTPUT = ROOT / "design" / "app-icon-review.png"
CANVAS = (1600, 1220)


def font(size: int, *, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "SFNS.ttf" if not bold else "SFNSRounded.ttf"
    path = Path("/System/Library/Fonts") / name
    return ImageFont.truetype(path, size)


def system_mask(size: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=round(size * 0.225), fill=255)
    return mask


def clipped(image: Image.Image, size: int, background: tuple[int, int, int]) -> Image.Image:
    resized = image.resize((size, size), Image.Resampling.LANCZOS).convert("RGBA")
    base = Image.new("RGBA", (size, size), (*background, 255))
    base.alpha_composite(resized)
    result = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    result.paste(base, mask=system_mask(size))
    return result


def main() -> None:
    canvas = Image.new("RGB", CANVAS, (235, 232, 224))
    draw = ImageDraw.Draw(canvas)
    ink = (42, 39, 34)
    muted = (103, 98, 89)

    draw.text((72, 58), "Pulse · B2 Open Day Ring", font=font(50, bold=True), fill=ink)
    draw.text((72, 126), "Approved geometry · deterministic flat-color production review", font=font(25), fill=muted)

    appearances = [
        ("DEFAULT", "AppIcon-Any.png", (247, 243, 233)),
        ("DARK", "AppIcon-Dark.png", (29, 27, 24)),
        ("TINTED SOURCE", "AppIcon-Tinted.png", (95, 95, 95)),
    ]
    for index, (label, filename, background) in enumerate(appearances):
        x = 72 + index * 350
        icon = Image.open(ICON_DIR / filename)
        preview = clipped(icon, 250, background)
        canvas.paste(preview.convert("RGB"), (x, 205), preview.getchannel("A"))
        draw.text((x, 475), label, font=font(18, bold=True), fill=ink)

    draw.line((72, 550, 1528, 550), fill=(192, 187, 177), width=2)
    draw.text((72, 588), "SMALL-SIZE RASTER CHECK", font=font(20, bold=True), fill=ink)
    draw.text((390, 588), "1× actual pixels above · nearest-neighbor enlargement below", font=font(18), fill=muted)

    source = Image.open(ICON_DIR / "AppIcon-Any.png")
    for column, size in enumerate((180, 60, 40, 29)):
        x = 72 + column * 370
        actual = clipped(source, size, (247, 243, 233))
        zoom = max(1, 232 // size)
        enlarged = actual.resize((size * zoom, size * zoom), Image.Resampling.NEAREST)
        draw.text((x, 656), f"{size} px", font=font(26, bold=True), fill=ink)
        actual_x = x + (250 - size) // 2
        canvas.paste(actual.convert("RGB"), (actual_x, 710), actual.getchannel("A"))
        zoom_x = x + (250 - enlarged.width) // 2
        canvas.paste(enlarged.convert("RGB"), (zoom_x, 940), enlarged.getchannel("A"))
        draw.text((x + 265, 1020), f"{zoom}×", font=font(20), fill=muted)

    canvas.save(OUTPUT, optimize=True)
    print(OUTPUT)


if __name__ == "__main__":
    main()
