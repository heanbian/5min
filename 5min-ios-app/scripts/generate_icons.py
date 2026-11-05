#!/usr/bin/env python3
"""Generate official 5min iOS App Icon / in-app logo / App Store artwork (aligned with Android)."""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "FiveMin" / "Assets.xcassets"
APPICON = ASSETS / "AppIcon.appiconset"
LOGO_SET = ASSETS / "Logo.imageset"
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
    # App Store rejects alpha on the 1024 marketing icon
    if path.name == "AppIcon.png" and img.mode == "RGBA":
        bg = Image.new("RGB", img.size, BG[:3])
        bg.paste(img, mask=img.split()[3])
        bg.save(path, format="PNG", optimize=True)
        return
    img.save(path, format="PNG", optimize=True)


def main() -> None:
    full = draw_mark(1024, for_adaptive_layer=False)
    fg = draw_mark(1080, for_adaptive_layer=True)

    APPICON.mkdir(parents=True, exist_ok=True)
    save(full, APPICON / "AppIcon.png")
    (APPICON / "Contents.json").write_text(
        """{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
""",
        encoding="utf-8",
    )

    LOGO_SET.mkdir(parents=True, exist_ok=True)
    if WEB_LOGO.exists():
        shutil.copyfile(WEB_LOGO, LOGO_SET / "logo.png")
    else:
        save(full.resize((216, 64), Image.Resampling.LANCZOS), LOGO_SET / "logo.png")
    (LOGO_SET / "Contents.json").write_text(
        """{
  "images" : [
    { "filename" : "logo.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "logo.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "logo.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
""",
        encoding="utf-8",
    )

    STORE.mkdir(parents=True, exist_ok=True)
    (STORE / "screenshots").mkdir(parents=True, exist_ok=True)
    save(full.resize((512, 512), Image.Resampling.LANCZOS), STORE / "ic_launcher_512.png")
    save(full, STORE / "ic_launcher_1024.png")
    save(fg, STORE / "ic_launcher_foreground_1080.png")
    if WEB_LOGO.exists():
        shutil.copyfile(WEB_LOGO, STORE / "logo.png")

    print("OK — iOS icons written")
    for p in (
        APPICON / "AppIcon.png",
        LOGO_SET / "logo.png",
        STORE / "ic_launcher_1024.png",
        STORE / "ic_launcher_512.png",
        STORE / "logo.png",
    ):
        if p.exists():
            print(" ", p.relative_to(ROOT))


if __name__ == "__main__":
    main()
