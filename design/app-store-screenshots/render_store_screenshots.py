#!/usr/bin/env python3
"""Render Pulse App Store screenshots from deterministic in-app captures.

The source images are real simulator screenshots (see `PulseStoreSourceUITests`).
This script only adds marketing composition: typography, paper, seals and device shells.
"""

from __future__ import annotations

import glob
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent
SOURCE = ROOT / "source"
OUTPUT = ROOT / "output"
SERIF = REPO / "pulse" / "Resources" / "Fonts" / "NotoSerifSC-Variable.ttf"

IPHONE_SIZE = (1284, 2778)
IPAD_SIZE = (2064, 2752)

COLORS = {
    "paper": "#F4EFE6",
    "paper_deep": "#ECE5D8",
    "ink": "#1E1A16",
    "muted": "#6F675E",
    "rule": "#E3DCD0",
    "seal": "#C8372D",
    "seal_wash": "#F3DDD5",
    "on_seal": "#FFF8F0",
    "night": "#14110E",
    "night_seal": "#E35541",
    "night_ink": "#F2EBDF",
}

COPY = {
    "zh": {
        "name": "一日一印",
        "titles": [
            "每天，只为一件事",
            "签到，就盖一枚印",
            "一个月，一本印谱",
            "一月回看，几句手记",
            "八种小组件，各有其时",
            "抬腕，就能签到",
            "完整加密备份，由你保管",
        ],
        "backup_subtitle": "包含签到、记事和原图",
        "watch_before": "签到前",
        "watch_after": "签到后",
    },
    "en": {
        "name": "Pulse",
        "titles": [
            "One thing. Every day.",
            "Check in. Leave a seal.",
            "A month of seals.",
            "A month, a few notes.",
            "Eight widget styles.",
            "Check in from your wrist.",
            "Your full encrypted backup, kept by you.",
        ],
        "backup_subtitle": "Includes check-ins, notes, and original photos",
        "watch_before": "Before",
        "watch_after": "After",
    },
}


def serif(size: int, weight: int = 800) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(SERIF), size=size)
    try:
        font.set_variation_by_axes([weight])
    except (OSError, ValueError):
        pass
    return font


def sans(lang: str, size: int) -> ImageFont.FreeTypeFont:
    if lang == "zh":
        pingfang = glob.glob(
            "/System/Library/AssetsV2/com_apple_MobileAsset_Font*/**/PingFang.ttc",
            recursive=True,
        )
        path = pingfang[0] if pingfang else "/System/Library/Fonts/STHeiti Medium.ttc"
        return ImageFont.truetype(path, size=size)
    return ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size=size)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(image.convert("RGB"), size, method=Image.Resampling.LANCZOS)


def seal(size: int, text: str, color: str, seed: int, weight: int = 900) -> Image.Image:
    """A seal impression: the face in ink, the inscription carved out, the rim and ink a little uneven."""
    rng = random.Random(seed)
    scale = 3
    side = size * scale
    mask = Image.new("L", (side, side), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, side - 1, side - 1), round(side * 0.075), fill=255)
    font = serif(round(side * (0.78 if len(text) == 1 else 0.56)), weight)
    box = draw.textbbox((0, 0), text, font=font, anchor="mm")
    offset_y = -(box[1] + box[3]) / 2
    draw.text((side / 2, side / 2 + offset_y), text, font=font, fill=0, anchor="mm")
    for _ in range(int(side / 9)):
        edge = rng.randrange(4)
        along = rng.uniform(0, side)
        radius = side * rng.uniform(0.004, 0.012)
        bite = radius * rng.uniform(0.3, 0.8)
        cx, cy = {
            0: (along, bite - radius),
            1: (side - bite + radius, along),
            2: (along, side - bite + radius),
            3: (bite - radius, along),
        }[edge]
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=0)
    for _ in range(int(side * side / 900)):
        cx, cy = rng.uniform(0, side), rng.uniform(0, side)
        radius = side * rng.uniform(0.0012, 0.003)
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=rng.randrange(40, 170))
    pressure = Image.new("L", (side, side), 0)
    angle = rng.uniform(0, math.tau)
    pcx = side / 2 + math.cos(angle) * side * 0.62
    pcy = side / 2 + math.sin(angle) * side * 0.62
    ImageDraw.Draw(pressure).ellipse(
        (pcx - side * 0.7, pcy - side * 0.7, pcx + side * 0.7, pcy + side * 0.7), fill=48
    )
    pressure = pressure.filter(ImageFilter.GaussianBlur(side * 0.18))
    mask = ImageChops.subtract(mask, pressure)
    layer = Image.new("RGBA", (side, side), color)
    layer.putalpha(mask)
    return layer.resize((size, size), Image.Resampling.LANCZOS)


def stamp(canvas: Image.Image, center: tuple[int, int], size: int, text: str, color: str, angle: float, seed: int) -> None:
    impression = seal(size, text, color, seed).rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    canvas.alpha_composite(
        impression, (round(center[0] - impression.width / 2), round(center[1] - impression.height / 2))
    )


def make_phone(source: Path, width: int, shadow: bool = True) -> Image.Image:
    screen_w = width - 48
    screen_h = round(screen_w * 2622 / 1206)
    outer_h = screen_h + 48
    margin = 72 if shadow else 0
    layer = Image.new("RGBA", (width + margin * 2, outer_h + margin * 2), (0, 0, 0, 0))

    if shadow:
        shadow_layer = Image.new("RGBA", layer.size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow_layer).rounded_rectangle(
            (margin + 8, margin + 22, margin + width + 8, margin + outer_h + 22),
            radius=112,
            fill=(40, 24, 16, 92),
        )
        layer.alpha_composite(shadow_layer.filter(ImageFilter.GaussianBlur(36)))

    body = Image.new("RGBA", (width, outer_h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle((0, 0, width - 1, outer_h - 1), radius=112, fill="#151210")
    screenshot = contain(Image.open(source), (screen_w, screen_h))
    body.paste(screenshot, (24, 24), rounded_mask((screen_w, screen_h), 88))
    bd.rounded_rectangle((width // 2 - 112, 42, width // 2 + 112, 92), radius=25, fill="#050403")
    layer.alpha_composite(body, (margin, margin))
    return layer


def make_tablet(source: Path, width: int) -> Image.Image:
    screen_w = width - 46
    screen_h = round(screen_w * 2752 / 2064)
    outer_h = screen_h + 46
    margin = 70
    layer = Image.new("RGBA", (width + margin * 2, outer_h + margin * 2), (0, 0, 0, 0))
    shadow_layer = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow_layer).rounded_rectangle(
        (margin + 8, margin + 24, margin + width + 8, margin + outer_h + 24),
        radius=72,
        fill=(40, 24, 16, 84),
    )
    layer.alpha_composite(shadow_layer.filter(ImageFilter.GaussianBlur(36)))
    body = Image.new("RGBA", (width, outer_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(body)
    draw.rounded_rectangle((0, 0, width - 1, outer_h - 1), radius=70, fill="#171412")
    screenshot = contain(Image.open(source), (screen_w, screen_h))
    body.paste(screenshot, (23, 23), rounded_mask((screen_w, screen_h), 52))
    draw.ellipse((width // 2 - 7, 8, width // 2 + 7, 22), fill="#34302C")
    layer.alpha_composite(body, (margin, margin))
    return layer


def make_watch(source: Path, width: int) -> Image.Image:
    screen_w = width - 52
    screen_h = round(screen_w * 514 / 422)
    body_h = screen_h + 52
    strap_w = round(width * 0.46)
    strap_top = 170
    layer_h = body_h + strap_top * 2
    layer = Image.new("RGBA", (width + 80, layer_h), (0, 0, 0, 0))
    cx = layer.width // 2
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle(
        (cx - strap_w // 2, 0, cx + strap_w // 2, layer_h),
        radius=strap_w // 3,
        fill="#2A2420",
    )
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (40 + 8, strap_top + 18, 40 + width + 8, strap_top + body_h + 18),
        radius=width // 4,
        fill=(0, 0, 0, 120),
    )
    layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(28)))
    draw.rounded_rectangle(
        (40, strap_top, 40 + width, strap_top + body_h),
        radius=width // 4,
        fill="#3A3430",
        outline="#5A524C",
        width=5,
    )
    screen = contain(Image.open(source), (screen_w, screen_h))
    layer.paste(screen, (66, strap_top + 26), rounded_mask((screen_w, screen_h), width // 5))
    draw.rounded_rectangle(
        (40 + width - 4, strap_top + 120, 40 + width + 22, strap_top + 220),
        radius=12,
        fill="#4A433E",
    )
    return layer


def draw_header(
    canvas: Image.Image,
    lang: str,
    number: int,
    title: str,
    *,
    ink: str = COLORS["ink"],
    accent: str = COLORS["seal"],
    left: int = 96,
    top: int = 104,
    max_width: int | None = None,
    title_size: int = 100,
    name_size: int = 31,
    total: int = 7,
) -> int:
    draw = ImageDraw.Draw(canvas)
    max_width = max_width or canvas.width - left * 2
    meta_font = sans(lang, name_size)
    draw.text((left, top), COPY[lang]["name"], font=meta_font, fill=accent)
    name_width = draw.textlength(COPY[lang]["name"], font=meta_font)
    draw.text((left + name_width + 26, top), f"{number:02d} / {total:02d}", font=meta_font, fill=ink)
    title_top = top + name_size + 64
    title_font = serif(title_size, 800)
    lines = wrap_text(draw, title, title_font, max_width)
    line_height = round(title_size * (1.2 if lang == "en" else 1.32))
    for index, line in enumerate(lines):
        draw.text((left, title_top + line_height * index), line, font=title_font, fill=ink)
    return title_top + line_height * len(lines)


def wrap_text(draw: ImageDraw.ImageDraw, text: str, text_font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    if draw.textlength(text, font=text_font) <= max_width:
        return [text]
    if " " in text:
        lines: list[str] = []
        current = ""
        for word in text.split():
            candidate = word if not current else f"{current} {word}"
            if draw.textlength(candidate, font=text_font) <= max_width:
                current = candidate
            else:
                if current:
                    lines.append(current)
                current = word
        if current:
            lines.append(current)
        return lines
    # Chinese titles break after a comma when they can, never inside a phrase.
    if "，" in text:
        head, tail = text.split("，", 1)
        return [head + "，", tail]
    lines = []
    current = ""
    for character in text:
        candidate = current + character
        if draw.textlength(candidate, font=text_font) <= max_width:
            current = candidate
        else:
            lines.append(current)
            current = character
    if current:
        lines.append(current)
    return lines


def paste_center(canvas: Image.Image, layer: Image.Image, y: int, x_offset: int = 0) -> None:
    x = (canvas.width - layer.width) // 2 + x_offset
    canvas.alpha_composite(layer, (x, y))


def save_rgb(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(path, "PNG", optimize=True)


def panorama(size: tuple[int, int], page_width: int, bottoms: tuple[int, int]) -> Image.Image:
    """Three pages on one sheet: seals pressed across each seam so the pages read as one strip."""
    image = Image.new("RGBA", size, COLORS["paper"])
    unit = page_width / 1284
    stamp(image, (page_width, bottoms[0]), round(560 * unit), "印", COLORS["seal"], -7, 11)
    stamp(image, (page_width * 2, bottoms[1]), round(430 * unit), "27", COLORS["seal"], 5, 23)
    stamp(image, (round(page_width * 0.06), bottoms[1] + round(40 * unit)), round(260 * unit), "26", COLORS["seal"], -4, 31)
    stamp(image, (round(page_width * 2.95), bottoms[0] - round(60 * unit)), round(300 * unit), "印", COLORS["seal"], 8, 47)
    return image


def render_phone_language(lang: str) -> list[Path]:
    source_dir = SOURCE / "iphone" / lang
    destination = OUTPUT / "iphone" / lang
    titles = COPY[lang]["titles"]
    long_background = panorama((IPHONE_SIZE[0] * 3, IPHONE_SIZE[1]), IPHONE_SIZE[0], (2440, 2560))
    paths: list[Path] = []

    for index, source_name in enumerate(["01-today-before.png", "02-today-after.png", "03-history.png"]):
        page = long_background.crop(
            (index * IPHONE_SIZE[0], 0, (index + 1) * IPHONE_SIZE[0], IPHONE_SIZE[1])
        ).convert("RGBA")
        draw_header(page, lang, index + 1, titles[index], title_size=100 if lang == "zh" else 88)
        phone = make_phone(source_dir / source_name, 888)
        paste_center(page, phone, 610)
        path = destination / f"{index + 1:02d}.png"
        save_rgb(page, path)
        paths.append(path)

    page4 = Image.new("RGBA", IPHONE_SIZE, COLORS["paper"])
    ImageDraw.Draw(page4).rectangle((78, 0, 84, IPHONE_SIZE[1]), fill=COLORS["seal_wash"])
    draw_header(page4, lang, 4, titles[3], left=122, max_width=1090, title_size=96 if lang == "zh" else 88)
    history = make_phone(source_dir / "03-history.png", 660).rotate(4.2, resample=Image.Resampling.BICUBIC, expand=True)
    journal = make_phone(source_dir / "04-journal.png", 690).rotate(-4.8, resample=Image.Resampling.BICUBIC, expand=True)
    page4.alpha_composite(history, (-150, 810))
    page4.alpha_composite(journal, (590, 690))
    stamp(page4, (1120, 2560), 300, "印", COLORS["seal"], -6, 53)
    path = destination / "04.png"
    save_rgb(page4, path)
    paths.append(path)

    page5 = Image.new("RGBA", IPHONE_SIZE, COLORS["seal"])
    d5 = ImageDraw.Draw(page5)
    d5.text((20, 360), "8", font=serif(1180, 900), fill="#B8322A")
    draw_header(page5, lang, 5, titles[4], ink=COLORS["on_seal"], accent=COLORS["on_seal"], max_width=1110, title_size=92)
    widgets = make_phone(source_dir / "05-widgets.png", 860)
    paste_center(page5, widgets, 690, x_offset=90)
    path = destination / "05.png"
    save_rgb(page5, path)
    paths.append(path)

    page6 = Image.new("RGBA", IPHONE_SIZE, COLORS["night"])
    d6 = ImageDraw.Draw(page6)
    draw_header(page6, lang, 6, titles[5], ink=COLORS["night_ink"], accent=COLORS["night_seal"], max_width=1120, title_size=96 if lang == "zh" else 86)
    before = make_watch(SOURCE / "watch" / lang / "01-ready.png", 500).rotate(-6, Image.Resampling.BICUBIC, expand=True)
    after = make_watch(SOURCE / "watch" / lang / "02-committed.png", 500).rotate(7, Image.Resampling.BICUBIC, expand=True)
    page6.alpha_composite(before, (10, 720))
    page6.alpha_composite(after, (650, 1060))
    label_font = sans(lang, 32)
    for (x, y, text, fill, ink) in (
        (105, 2390, COPY[lang]["watch_before"], COLORS["night_ink"], COLORS["night"]),
        (995, 2460, COPY[lang]["watch_after"], COLORS["night_seal"], COLORS["on_seal"]),
    ):
        width = round(d6.textlength(text, font=label_font)) + 64
        d6.rounded_rectangle((x, y, x + width, y + 70), radius=35, fill=fill)
        d6.text((x + 32, y + 35), text, font=label_font, fill=ink, anchor="lm")
    path = destination / "06.png"
    save_rgb(page6, path)
    paths.append(path)

    page7 = Image.new("RGBA", IPHONE_SIZE, COLORS["paper_deep"])
    d7 = ImageDraw.Draw(page7)
    text_bottom = draw_header(page7, lang, 7, titles[6], max_width=1110, title_size=88)
    d7.text((96, text_bottom + 18), COPY[lang]["backup_subtitle"], font=sans(lang, 37), fill=COLORS["muted"])
    stamp(page7, (1150, 2600), 280, "印", COLORS["seal"], 7, 61)
    backup_source = "backup.png" if lang == "zh" else "backup-en.png"
    backup = make_phone(SOURCE / "review" / backup_source, 850)
    paste_center(page7, backup, 720)
    path = destination / "07.png"
    save_rgb(page7, path)
    paths.append(path)
    return paths


def render_ipad_language(lang: str) -> list[Path]:
    source_dir = SOURCE / "ipad" / lang
    destination = OUTPUT / "ipad" / lang
    titles = COPY[lang]["titles"]
    long_background = panorama((IPAD_SIZE[0] * 3, IPAD_SIZE[1]), IPAD_SIZE[0], (2560, 2620))
    paths: list[Path] = []
    names = ["01-today-before.png", "02-today-after.png", "03-history.png", "04-journal.png", "05-widgets.png"]
    for index, name in enumerate(names):
        ink, accent = COLORS["ink"], COLORS["seal"]
        if index < 3:
            page = long_background.crop(
                (index * IPAD_SIZE[0], 0, (index + 1) * IPAD_SIZE[0], IPAD_SIZE[1])
            ).convert("RGBA")
        elif index == 3:
            page = Image.new("RGBA", IPAD_SIZE, COLORS["paper"])
            ImageDraw.Draw(page).rectangle((110, 0, 118, IPAD_SIZE[1]), fill=COLORS["seal_wash"])
        else:
            page = Image.new("RGBA", IPAD_SIZE, COLORS["seal"])
            ImageDraw.Draw(page).text((1240, 980), "8", font=serif(1700, 900), fill="#B8322A")
            ink, accent = COLORS["on_seal"], COLORS["on_seal"]
        draw_header(
            page,
            lang,
            index + 1,
            titles[index],
            ink=ink,
            accent=accent,
            left=150,
            top=92,
            max_width=1764,
            title_size=108,
            name_size=34,
            total=5,
        )
        tablet = make_tablet(source_dir / name, 1530)
        paste_center(page, tablet, 430)
        path = destination / f"{index + 1:02d}.png"
        save_rgb(page, path)
        paths.append(path)
    return paths


def render_watch_and_review() -> None:
    for lang in ("zh", "en"):
        for name in ("01-ready.png", "02-committed.png"):
            image = Image.open(SOURCE / "watch" / lang / name).convert("RGB")
            save_rgb(image, OUTPUT / "watch" / lang / name)
    for name in ("advanced-features-zh.png", "backup.png", "backup-en.png"):
        image = Image.open(SOURCE / "review" / name).convert("RGB")
        save_rgb(image, OUTPUT / "review" / name)
    advanced = Image.open(SOURCE / "review" / "advanced-features-zh.png").convert("RGB")
    review_crop = advanced.crop((0, 888, 1206, 2622)).resize((640, 920), Image.Resampling.LANCZOS)
    save_rgb(review_crop, OUTPUT / "review" / "advanced-features-review-640x920.png")


def make_contact_sheet(paths: list[Path], destination: Path) -> None:
    thumb_w = 330
    thumb_h = round(thumb_w * IPHONE_SIZE[1] / IPHONE_SIZE[0])
    columns = 4
    rows = math.ceil(len(paths) / columns)
    gutter = 30
    sheet = Image.new(
        "RGB",
        (columns * thumb_w + (columns + 1) * gutter, rows * thumb_h + (rows + 1) * gutter),
        "#DCD5C8",
    )
    for index, path in enumerate(paths):
        image = Image.open(path).convert("RGB").resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        x = gutter + (index % columns) * (thumb_w + gutter)
        y = gutter + (index // columns) * (thumb_h + gutter)
        sheet.paste(image, (x, y))
    save_rgb(sheet, destination)


def main() -> None:
    all_phone_paths: dict[str, list[Path]] = {}
    for lang in ("zh", "en"):
        all_phone_paths[lang] = render_phone_language(lang)
        render_ipad_language(lang)
    render_watch_and_review()
    for lang, paths in all_phone_paths.items():
        make_contact_sheet(paths, OUTPUT / "contact-sheets" / f"iphone-{lang}.png")
    print(f"Rendered App Store assets to {OUTPUT}")


if __name__ == "__main__":
    main()
