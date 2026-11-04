#!/usr/bin/env python3
"""Generate official 5min HarmonyOS app icons / store artwork (aligned with Android brand)."""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
APP_MEDIA = ROOT / "AppScope" / "resources" / "base" / "media"
ENTRY_MEDIA = ROOT / "entry" / "src" / "main" / "resources" / "base" / "media"
STORE = ROOT / "store" / "artwork"
WEB_LOGO = ROOT.parent / "5min-web" / "img" / "logo.png"

BRAND = (0x2F, 0x9A, 0x68, 255)
INK = (0x1F, 0x2A, 0x24, 255)
BG = (0xEE, 0xF6, 0xF1, 255)
GLOW = (0xDF, 0xF0, 0xE6, 255)
RING = (0xCF, 0xE0, 0xD6, 255)
WHITE = (255, 255, 255, 255)


def _font(size: int) -> ImageFont.ImageFont:
    for path in (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ):
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def draw_mark(size: int, *, for_adaptive_layer: bool = False) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0) if for_adaptive_layer else BG)
    draw = ImageDraw.Draw(img)
    cx = cy = size / 2
    if not for_adaptive_layer:
        glow_r = size * 0.42
        draw.ellipse((cx - glow_r, cy - glow_r, cx + glow_r, cy + glow_r), fill=GLOW)
    outer_r = size * (0.34 if for_adaptive_layer else 0.36)
    stroke = max(2.0, size * 0.055)
    bbox = (cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r)
    draw.arc(bbox, start=0, end=360, fill=RING, width=int(round(stroke)))
    draw.arc(bbox, start=-90, end=250, fill=BRAND, width=int(round(stroke)))
    inner_r = outer_r - stroke * 1.35
    draw.ellipse(
        (cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r),
        fill=WHITE if for_adaptive_layer else (255, 255, 255, 235),
    )
    font = _font(int(size * 0.42))
    tb = draw.textbbox((0, 0), "5", font=font)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    draw.text(
        (cx - tw / 2 - tb[0], cy - th / 2 - tb[1] - size * 0.01),
        "5",
        font=font,
        fill=INK,
    )
    return img


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)


def main() -> None:
    full = draw_mark(1024, for_adaptive_layer=False)
    fg = draw_mark(1080, for_adaptive_layer=True)
    bg = Image.new("RGBA", (1080, 1080), BG)
    g = ImageDraw.Draw(bg)
    g.ellipse((180, 180, 900, 900), fill=GLOW)

    # Layered adaptive icon (HarmonyOS)
    save(bg.resize((512, 512), Image.Resampling.LANCZOS), APP_MEDIA / "background.png")
    save(fg.resize((512, 512), Image.Resampling.LANCZOS), APP_MEDIA / "foreground.png")
    (APP_MEDIA / "layered_image.json").write_text(
        '{\n  "layered-image": {\n    "background": "$media:background",\n'
        '    "foreground": "$media:foreground"\n  }\n}\n',
        encoding="utf-8",
    )
    save(full.resize((512, 512), Image.Resampling.LANCZOS), APP_MEDIA / "app_icon.png")
    save(full.resize((512, 512), Image.Resampling.LANCZOS), ENTRY_MEDIA / "icon.png")

    # In-app wordmark
    if WEB_LOGO.exists():
        shutil.copyfile(WEB_LOGO, ENTRY_MEDIA / "logo.png")
        shutil.copyfile(WEB_LOGO, APP_MEDIA / "logo.png")

    # Store / AppGallery artwork
    save(full.resize((512, 512), Image.Resampling.LANCZOS), STORE / "ic_launcher_512.png")
    save(full, STORE / "ic_launcher_1024.png")
    save(fg, STORE / "ic_launcher_foreground_1080.png")

    print("OK — Harmony icons written")
    for p in (
        APP_MEDIA / "app_icon.png",
        APP_MEDIA / "foreground.png",
        APP_MEDIA / "background.png",
        ENTRY_MEDIA / "icon.png",
        ENTRY_MEDIA / "logo.png",
        STORE / "ic_launcher_512.png",
    ):
        if p.exists():
            print(" ", p.relative_to(ROOT))


if __name__ == "__main__":
    main()
