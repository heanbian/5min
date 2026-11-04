#!/usr/bin/env python3
"""Generate official 5min Android launcher / Play Store icons (all densities)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "app" / "src" / "main" / "res"
PLAY = ROOT / "store" / "artwork"

BRAND = (0x2F, 0x9A, 0x68, 255)
INK = (0x1F, 0x2A, 0x24, 255)
BG = (0xEE, 0xF6, 0xF1, 255)
GLOW = (0xDF, 0xF0, 0xE6, 255)
RING = (0xCF, 0xE0, 0xD6, 255)
WHITE = (255, 255, 255, 255)

LEGACY = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
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
        draw.ellipse(
            (cx - glow_r, cy - glow_r, cx + glow_r, cy + glow_r),
            fill=GLOW,
        )

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
    text = "5"
    tb = draw.textbbox((0, 0), text, font=font)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    tx = cx - tw / 2 - tb[0]
    ty = cy - th / 2 - tb[1] - size * 0.01
    draw.text((tx, ty), text, font=font, fill=INK)
    return img


def draw_round_mask(src: Image.Image) -> Image.Image:
    size = src.size[0]
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    out.paste(src, (0, 0))
    out.putalpha(mask)
    return out


def save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)


def main() -> None:
    full_master = draw_mark(1024, for_adaptive_layer=False)
    fg_master = draw_mark(1080, for_adaptive_layer=True)

    for folder, px in LEGACY.items():
        square = full_master.resize((px, px), Image.Resampling.LANCZOS)
        save_png(square, RES / folder / "ic_launcher.png")
        save_png(draw_round_mask(square), RES / folder / "ic_launcher_round.png")

    save_png(full_master.resize((512, 512), Image.Resampling.LANCZOS), PLAY / "ic_launcher_512.png")
    save_png(full_master, PLAY / "ic_launcher_1024.png")
    save_png(fg_master, PLAY / "ic_launcher_foreground_1080.png")

    print("OK — launcher icons written")
    for p in sorted(PLAY.glob("*.png")):
        print(" ", p.relative_to(ROOT))
    for density in LEGACY:
        print(f"  {density}/ic_launcher.png + ic_launcher_round.png")


if __name__ == "__main__":
    main()
