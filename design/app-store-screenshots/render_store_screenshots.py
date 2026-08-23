#!/usr/bin/env python3
"""Render Pulse App Store screenshots from deterministic in-app captures.

The source images are real simulator screenshots. This script only adds
marketing composition: typography, brand color fields, and device shells.
"""

from __future__ import annotations

import glob
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "source"
OUTPUT = ROOT / "output"

IPHONE_SIZE = (1284, 2778)
IPAD_SIZE = (2064, 2752)

COLORS = {
    "quiet_canvas": "#F7F7E8",
    "quiet_surface": "#FEFEEA",
    "quiet_ink": "#182017",
    "quiet_muted": "#62705D",
    "quiet_green": "#4BAA5A",
    "quiet_green_deep": "#2C713A",
    "quiet_green_soft": "#D8EDC8",
    "paper": "#FBF7EA",
    "water": "#70AD91",
    "yellow": "#E6C979",
    "pink": "#D942A6",
    "watch_top": "#04152E",
    "watch_bottom": "#075EA8",
    "watch_front": "#0789E6",
    "white": "#FFFFFF",
}

COPY = {
    "zh": {
        "name": "一日一印",
        "titles": [
            "每天，只为一件事",
            "今天，有了落点",
            "有来过，也有空白",
            "一月回看，几句手记",
            "八种小组件，各有其时",
            "抬腕，今日落印",
            "完整加密备份，由你保管",
        ],
        "backup_subtitle": "包含签到、记事和原图",
        "watch_before": "签到前",
        "watch_after": "签到后",
    },
    "en": {
        "name": "PULSE",
        "titles": [
            "One thing. Every day.",
            "Today, marked.",
            "Every mark. Every pause.",
            "A month of marks. A few notes.",
            "Eight Widget styles. Your rhythm.",
            "Check in, right on your wrist.",
            "Your full encrypted backup, kept by you.",
        ],
        "backup_subtitle": "Includes check-ins, notes, and original photos",
        "watch_before": "BEFORE",
        "watch_after": "AFTER",
    },
}


def font_path(lang: str, bold: bool = False) -> str:
    if lang == "zh":
        pingfang = glob.glob(
            "/System/Library/AssetsV2/com_apple_MobileAsset_Font*/**/PingFang.ttc",
            recursive=True,
        )
        if pingfang:
            return pingfang[0]
        return "/System/Library/Fonts/STHeiti Medium.ttc"
    if bold:
        return "/System/Library/Fonts/SFNSRounded.ttf"
    return "/System/Library/Fonts/SFNS.ttf"


def font(lang: str, size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(font_path(lang, bold), size=size)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(image.convert("RGB"), size, method=Image.Resampling.LANCZOS)


def make_phone(source: Path, width: int, shadow: bool = True) -> Image.Image:
    screen_w = width - 48
    screen_h = round(screen_w * 2622 / 1206)
    outer_h = screen_h + 48
    margin = 72 if shadow else 0
    layer = Image.new("RGBA", (width + margin * 2, outer_h + margin * 2), (0, 0, 0, 0))

    if shadow:
        shadow_layer = Image.new("RGBA", layer.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow_layer)
        sd.rounded_rectangle(
            (margin + 8, margin + 20, margin + width + 8, margin + outer_h + 20),
            radius=112,
            fill=(16, 27, 18, 105),
        )
        layer.alpha_composite(shadow_layer.filter(ImageFilter.GaussianBlur(34)))

    body = Image.new("RGBA", (width, outer_h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle((0, 0, width - 1, outer_h - 1), radius=112, fill="#111411")
    screenshot = contain(Image.open(source), (screen_w, screen_h))
    body.paste(screenshot, (24, 24), rounded_mask((screen_w, screen_h), 88))
    bd.rounded_rectangle(
        (width // 2 - 112, 42, width // 2 + 112, 92), radius=25, fill="#050605"
    )
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
        fill=(14, 25, 16, 90),
    )
    layer.alpha_composite(shadow_layer.filter(ImageFilter.GaussianBlur(34)))
    body = Image.new("RGBA", (width, outer_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(body)
    draw.rounded_rectangle((0, 0, width - 1, outer_h - 1), radius=70, fill="#161816")
    screenshot = contain(Image.open(source), (screen_w, screen_h))
    body.paste(screenshot, (23, 23), rounded_mask((screen_w, screen_h), 52))
    draw.ellipse((width // 2 - 7, 8, width // 2 + 7, 22), fill="#303430")
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
        fill="#1B201D",
    )
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (40 + 8, strap_top + 18, 40 + width + 8, strap_top + body_h + 18),
        radius=width // 4,
        fill=(0, 0, 0, 110),
    )
    layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(28)))
    draw.rounded_rectangle(
        (40, strap_top, 40 + width, strap_top + body_h),
        radius=width // 4,
        fill="#B9BDBA",
        outline="#F2F4F2",
        width=5,
    )
    screen = contain(Image.open(source), (screen_w, screen_h))
    layer.paste(screen, (66, strap_top + 26), rounded_mask((screen_w, screen_h), width // 5))
    draw.rounded_rectangle(
        (40 + width - 4, strap_top + 120, 40 + width + 22, strap_top + 220),
        radius=12,
        fill="#969B98",
    )
    return layer


def cubic_points(
    p0: tuple[float, float],
    p1: tuple[float, float],
    p2: tuple[float, float],
    p3: tuple[float, float],
    steps: int = 160,
) -> list[tuple[int, int]]:
    points: list[tuple[int, int]] = []
    for index in range(steps + 1):
        t = index / steps
        u = 1 - t
        x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
        points.append((round(x), round(y)))
    return points


def panorama(size: tuple[int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size, COLORS["quiet_canvas"])
    draw = ImageDraw.Draw(image)
    draw.ellipse((-width * 0.08, -height * 0.32, width * 0.29, height * 0.34), fill="#FFF4B8")
    draw.ellipse((width * 0.71, -height * 0.26, width * 1.05, height * 0.30), fill="#E9DDF0")

    main = cubic_points(
        (-width * 0.08, height * 0.78),
        (width * 0.22, height * 0.40),
        (width * 0.62, height * 0.92),
        (width * 1.06, height * 0.54),
    )
    draw.line(main, fill=COLORS["quiet_green_soft"], width=round(height * 0.34), joint="curve")
    draw.line(main, fill=COLORS["quiet_green"], width=round(height * 0.15), joint="curve")

    lower = cubic_points(
        (-width * 0.06, height * 1.02),
        (width * 0.30, height * 0.68),
        (width * 0.62, height * 1.12),
        (width * 1.06, height * 0.73),
    )
    draw.line(lower, fill=COLORS["quiet_green_deep"], width=round(height * 0.10), joint="curve")
    return image


def draw_header(
    canvas: Image.Image,
    lang: str,
    number: int,
    title: str,
    *,
    ink: str = COLORS["quiet_ink"],
    left: int = 96,
    top: int = 104,
    max_width: int | None = None,
    title_size: int = 104,
    name_size: int = 31,
) -> int:
    draw = ImageDraw.Draw(canvas)
    max_width = max_width or canvas.width - left * 2
    name_font = font(lang, name_size, bold=True)
    meta = f"{COPY[lang]['name']}   {number:02d} / 07"
    draw.text((left, top), meta, font=name_font, fill=ink, spacing=4)
    title_top = top + name_size + 66
    title_font = font(lang, title_size, bold=True)
    lines = wrap_text(draw, title, title_font, max_width)
    line_height = round(title_size * (1.18 if lang == "en" else 1.28))
    for index, line in enumerate(lines):
        draw.text((left, title_top + line_height * index), line, font=title_font, fill=ink)
    return title_top + line_height * len(lines)


def wrap_text(draw: ImageDraw.ImageDraw, text: str, text_font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    if draw.textlength(text, font=text_font) <= max_width:
        return [text]
    if " " in text:
        words = text.split()
        lines: list[str] = []
        current = ""
        for word in words:
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


def render_phone_language(lang: str) -> list[Path]:
    source_dir = SOURCE / "iphone" / lang
    destination = OUTPUT / "iphone" / lang
    titles = COPY[lang]["titles"]
    long_background = panorama((IPHONE_SIZE[0] * 3, IPHONE_SIZE[1]))
    paths: list[Path] = []

    for index, source_name in enumerate(
        ["01-today-before.png", "02-today-after.png", "03-history.png"]
    ):
        background = long_background.crop(
            (index * IPHONE_SIZE[0], 0, (index + 1) * IPHONE_SIZE[0], IPHONE_SIZE[1])
        ).convert("RGBA")
        draw_header(background, lang, index + 1, titles[index])
        phone = make_phone(source_dir / source_name, 888)
        paste_center(background, phone, 610)
        path = destination / f"{index + 1:02d}.png"
        save_rgb(background, path)
        paths.append(path)

    page4 = Image.new("RGBA", IPHONE_SIZE, COLORS["paper"])
    d4 = ImageDraw.Draw(page4)
    d4.rectangle((78, 0, 88, IPHONE_SIZE[1]), fill="#D8CDB1")
    draw_header(page4, lang, 4, titles[3], left=122, max_width=1090, title_size=98)
    history = make_phone(source_dir / "03-history.png", 660).rotate(4.2, resample=Image.Resampling.BICUBIC, expand=True)
    journal = make_phone(source_dir / "04-journal.png", 690).rotate(-4.8, resample=Image.Resampling.BICUBIC, expand=True)
    page4.alpha_composite(history, (-150, 810))
    page4.alpha_composite(journal, (590, 690))
    path = destination / "04.png"
    save_rgb(page4, path)
    paths.append(path)

    page5 = Image.new("RGBA", IPHONE_SIZE, COLORS["water"])
    d5 = ImageDraw.Draw(page5)
    d5.ellipse((-360, 1460, 860, 2680), fill="#9CCDB8")
    d5.ellipse((800, 2050, 1510, 2760), fill=COLORS["yellow"])
    giant = font(lang, 620, bold=True)
    d5.text((50, 460), "8", font=giant, fill="#5D9B81")
    draw_header(page5, lang, 5, titles[4], ink="#11251D", max_width=1110, title_size=91)
    widgets = make_phone(source_dir / "05-widgets.png", 860)
    paste_center(page5, widgets, 690, x_offset=100)
    path = destination / "05.png"
    save_rgb(page5, path)
    paths.append(path)

    page6 = Image.new("RGBA", IPHONE_SIZE, COLORS["watch_top"])
    d6 = ImageDraw.Draw(page6)
    d6.ellipse((-450, 1700, 1320, 3470), fill=COLORS["watch_bottom"])
    d6.ellipse((470, 2080, 1740, 3350), fill=COLORS["watch_front"])
    draw_header(page6, lang, 6, titles[5], ink="#F4F8F3", max_width=1120, title_size=96)
    before = make_watch(SOURCE / "watch" / lang / "01-ready.png", 500).rotate(-6, Image.Resampling.BICUBIC, expand=True)
    after = make_watch(SOURCE / "watch" / lang / "02-committed.png", 500).rotate(7, Image.Resampling.BICUBIC, expand=True)
    page6.alpha_composite(before, (10, 720))
    page6.alpha_composite(after, (650, 1060))
    label_font = font(lang, 30, bold=True)
    d6.rounded_rectangle((105, 2390, 315, 2458), radius=34, fill="#FFFFFF")
    d6.text((133, 2404), COPY[lang]["watch_before"], font=label_font, fill=COLORS["watch_top"])
    d6.rounded_rectangle((995, 2460, 1210, 2528), radius=34, fill="#91D55B")
    d6.text((1022, 2474), COPY[lang]["watch_after"], font=label_font, fill="#102013")
    path = destination / "06.png"
    save_rgb(page6, path)
    paths.append(path)

    page7 = Image.new("RGBA", IPHONE_SIZE, "#163E28")
    d7 = ImageDraw.Draw(page7)
    d7.ellipse((-250, 2070, 800, 3120), fill="#215C39")
    d7.ellipse((720, 2220, 1520, 3020), fill="#2D6A4F")
    text_bottom = draw_header(page7, lang, 7, titles[6], ink="#F7F7E8", max_width=1110, title_size=90)
    subtitle_font = font(lang, 37)
    d7.text((96, text_bottom + 22), COPY[lang]["backup_subtitle"], font=subtitle_font, fill="#CFE0D0")
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
    long_background = panorama((IPAD_SIZE[0] * 3, IPAD_SIZE[1]))
    paths: list[Path] = []
    names = [
        "01-today-before.png",
        "02-today-after.png",
        "03-history.png",
        "04-journal.png",
        "05-widgets.png",
    ]
    for index, name in enumerate(names):
        if index < 3:
            page = long_background.crop(
                (index * IPAD_SIZE[0], 0, (index + 1) * IPAD_SIZE[0], IPAD_SIZE[1])
            ).convert("RGBA")
        elif index == 3:
            page = Image.new("RGBA", IPAD_SIZE, COLORS["paper"])
            ImageDraw.Draw(page).rectangle((110, 0, 122, IPAD_SIZE[1]), fill="#D8CDB1")
        else:
            page = Image.new("RGBA", IPAD_SIZE, COLORS["water"])
            pd = ImageDraw.Draw(page)
            pd.ellipse((-520, 1460, 1100, 3080), fill="#9CCDB8")
            pd.ellipse((1450, 2200, 2250, 3000), fill=COLORS["yellow"])
        ink = "#11251D" if index == 4 else COLORS["quiet_ink"]
        draw_header(
            page,
            lang,
            index + 1,
            titles[index],
            ink=ink,
            left=150,
            top=92,
            max_width=1764,
            title_size=112,
            name_size=34,
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
    review_crop = advanced.crop((0, 888, 1206, 2622)).resize(
        (640, 920), Image.Resampling.LANCZOS
    )
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
        "#E4E7DF",
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
