#!/usr/bin/env python3
"""Generate App Store Connect product-page Header / Search creative assets.

Sizes (Apple creative-assets specs):
  - Universal (header + search): 5244 × 2950 PNG only
  - Header 21:9 only:            3840 × 1646 JPEG/PNG
  - Search 3:2:                  3840 × 2560 (max) JPEG/PNG

No alpha channel.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "store" / "artwork"
SHOTS = ART / "screenshots"
OUT = ART / "creative"

# Brand (FiveMinTheme)
BRAND = (0x2F, 0x9A, 0x68)
BRAND_STRONG = (0x24, 0x85, 0x56)
INK = (0x1A, 0x2E, 0x24)
MUTED = (0x5A, 0x6B, 0x62)
BG_TOP = (0xF4, 0xFB, 0xF7)
BG_MID = (0xE8, 0xF5, 0xEE)
BG_BOT = (0xD8, 0xEC, 0xE2)

PINGFANG = (
    "/System/Library/AssetsV2/com_apple_MobileAsset_Font8/"
    "86ba2c91f017a3749571a82f2c6d890ac7ffb2fb.asset/AssetData/PingFang.ttc"
)
FALLBACK = "/Library/Fonts/Arial Unicode.ttf"


def font(size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    for path in (PINGFANG, FALLBACK):
        try:
            return ImageFont.truetype(path, size=size, index=index)
        except OSError:
            continue
    return ImageFont.load_default()


def gradient(size: tuple[int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGB", size, BG_TOP)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        if t < 0.55:
            u = t / 0.55
            r = int(BG_TOP[0] + (BG_MID[0] - BG_TOP[0]) * u)
            g = int(BG_TOP[1] + (BG_MID[1] - BG_TOP[1]) * u)
            b = int(BG_TOP[2] + (BG_MID[2] - BG_TOP[2]) * u)
        else:
            u = (t - 0.55) / 0.45
            r = int(BG_MID[0] + (BG_BOT[0] - BG_MID[0]) * u)
            g = int(BG_MID[1] + (BG_BOT[1] - BG_MID[1]) * u)
            b = int(BG_MID[2] + (BG_BOT[2] - BG_MID[2]) * u)
        for x in range(w):
            # Subtle radial lift toward center-top.
            dx = (x - w * 0.5) / (w * 0.5)
            dy = (y - h * 0.28) / (h * 0.55)
            glow = max(0.0, 1.0 - math.sqrt(dx * dx + dy * dy))
            glow *= 0.12
            px[x, y] = (
                min(255, int(r + (255 - r) * glow)),
                min(255, int(g + (255 - g) * glow)),
                min(255, int(b + (255 - b) * glow)),
            )
    return img


def rounded_shadow(
    shot: Image.Image, radius: int, pad: int = 28
) -> Image.Image:
    """Phone-like rounded frame with soft drop shadow (opaque)."""
    shot = shot.convert("RGB")
    w, h = shot.size
    canvas = Image.new("RGB", (w + pad * 2, h + pad * 2 + 18), BG_MID)
    # Shadow
    shadow = Image.new("L", (w + 20, h + 20), 0)
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((10, 16, w + 10, h + 16), radius=radius + 4, fill=90)
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas.paste(
        tuple(max(0, c - 28) for c in BG_MID),
        (pad - 10, pad - 4),
        shadow,
    )
    # Frame
    frame = Image.new("RGB", (w, h), (255, 255, 255))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=255)
    frame.paste(shot, (0, 0))
    # Soft border
    border = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle(
        (0, 0, w - 1, h - 1), radius=radius, outline=(36, 70, 52, 40), width=3
    )
    frame = Image.alpha_composite(frame.convert("RGBA"), border).convert("RGB")
    canvas.paste(frame, (pad, pad), mask)
    return canvas


def paste_center(base: Image.Image, overlay: Image.Image, box: tuple[int, int, int, int]) -> None:
    """Scale overlay to fit inside box, centered."""
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    ow, oh = overlay.size
    scale = min(bw / ow, bh / oh)
    nw, nh = max(1, int(ow * scale)), max(1, int(oh * scale))
    resized = overlay.resize((nw, nh), Image.Resampling.LANCZOS)
    x = x0 + (bw - nw) // 2
    y = y0 + (bh - nh) // 2
    base.paste(resized, (x, y))


def draw_copy(
    draw: ImageDraw.ImageDraw,
    cx: int,
    top: int,
    title_size: int,
    sub_size: int,
    gap: int,
) -> int:
    title = "如厕计时器"
    sub = "端侧倒计时 · 习惯提醒 · 无账号无广告"
    brand = "5min"
    tf = font(title_size, index=2)  # Semibold-ish if available
    sf = font(sub_size, index=0)
    bf = font(int(title_size * 0.72), index=2)

    # Measure
    def w(text: str, f: ImageFont.ImageFont) -> int:
        return int(draw.textbbox((0, 0), text, font=f)[2])

    y = top
    draw.text((cx - w(brand, bf) // 2, y), brand, fill=BRAND_STRONG, font=bf)
    y += int(title_size * 0.85) + gap // 2
    draw.text((cx - w(title, tf) // 2, y), title, fill=INK, font=tf)
    y += title_size + gap
    draw.text((cx - w(sub, sf) // 2, y), sub, fill=MUTED, font=sf)
    return y + sub_size


def build_universal() -> Image.Image:
    """5244×2950 — safe zone ~1402×962, centered, above midline."""
    W, H = 5244, 2950
    img = gradient((W, H))
    draw = ImageDraw.Draw(img)

    # Safe zone (Apple guidance)
    sw, sh = 1402, 962
    sx = (W - sw) // 2
    sy = H // 2 - sh  # sits just above midline
    # Optional: light card behind safe content
    card = Image.new("RGB", (sw + 80, sh + 100), (255, 255, 255))
    # Don't draw opaque card full — keep airy; soft ellipse glow instead
    glow = Image.new("L", (sw + 200, sh + 160), 0)
    ImageDraw.Draw(glow).ellipse((0, 0, sw + 199, sh + 159), fill=55)
    glow = glow.filter(ImageFilter.GaussianBlur(40))
    tint = Image.new("RGB", glow.size, (255, 255, 255))
    img.paste(tint, (sx - 100, sy - 40), glow)

    shot = Image.open(SHOTS / "iphone-medium-home.png")
    phone = rounded_shadow(shot, radius=72, pad=24)

    # Layout inside safe zone: text top, phone below
    text_bottom = draw_copy(draw, W // 2, sy + 12, title_size=96, sub_size=42, gap=28)
    phone_box = (sx + 40, text_bottom + 20, sx + sw - 40, sy + sh - 10)
    paste_center(img, phone, phone_box)
    return img


def build_header_219() -> Image.Image:
    """3840×1646 — safe zone ~1646×661 centered."""
    W, H = 3840, 1646
    img = gradient((W, H))
    draw = ImageDraw.Draw(img)

    sw, sh = 1646, 661
    sx = (W - sw) // 2
    sy = (H - sh) // 2

    glow = Image.new("L", (sw + 240, sh + 180), 0)
    ImageDraw.Draw(glow).ellipse((0, 0, sw + 239, sh + 179), fill=50)
    glow = glow.filter(ImageFilter.GaussianBlur(36))
    img.paste(Image.new("RGB", glow.size, (255, 255, 255)), (sx - 120, sy - 60), glow)

    # Split: copy left, phone right inside safe zone
    left_cx = sx + int(sw * 0.28)
    draw_copy(draw, left_cx, sy + 80, title_size=88, sub_size=36, gap=22)

    shot = Image.open(SHOTS / "iphone-medium-running.png")
    phone = rounded_shadow(shot, radius=64, pad=20)
    # Scale phone to fit right half of safe zone
    paste_center(img, phone, (sx + int(sw * 0.42), sy + 20, sx + sw - 20, sy + sh - 20))
    return img


def build_search_32() -> Image.Image:
    """3840×2560 (3:2 max) for Search Results."""
    W, H = 3840, 2560
    img = gradient((W, H))
    draw = ImageDraw.Draw(img)

    # Safe-ish center band
    text_bottom = draw_copy(draw, W // 2, int(H * 0.12), title_size=110, sub_size=46, gap=30)
    shot = Image.open(SHOTS / "iphone-medium-home.png")
    phone = rounded_shadow(shot, radius=70, pad=24)
    paste_center(img, phone, (int(W * 0.22), text_bottom + 40, int(W * 0.78), int(H * 0.92)))
    return img


def save_rgb_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rgb = img.convert("RGB")
    rgb.save(path, format="PNG", optimize=True)
    w, h = rgb.size
    print(f"wrote {path.name}  {w}x{h}  no-alpha")


def main() -> None:
    save_rgb_png(build_universal(), OUT / "header-universal-5244x2950.png")
    save_rgb_png(build_header_219(), OUT / "header-21x9-3840x1646.png")
    save_rgb_png(build_search_32(), OUT / "search-3x2-3840x2560.png")
    print(f"\nUpload ASC → 产品页面信息 → 标题:")
    print(f"  preferred: {OUT / 'header-universal-5244x2950.png'}")
    print(f"  or:        {OUT / 'header-21x9-3840x1646.png'}")
    print(f"Search tab:  {OUT / 'search-3x2-3840x2560.png'}")
    print("  (or reuse universal + check「在搜索结果中使用标题素材」)")


if __name__ == "__main__":
    main()
