#!/usr/bin/env python3
"""Sync Android launcher icons from the shared official artwork (same as iOS / Harmony).

Does not redraw the mark with system fonts — that drifted from other app ends.
Source of truth (first hit wins):
  1) 5min-android-app/store/artwork/ic_launcher_1024.png + ic_launcher_foreground_1080.png
  2) 5min-ios-app / 5min-harmony-app store artwork twins
"""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
RES = ROOT / "app" / "src" / "main" / "res"
PLAY = ROOT / "store" / "artwork"

LEGACY = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def _first_existing(paths: list[Path]) -> Path:
    for path in paths:
        if path.is_file():
            return path
    raise FileNotFoundError("missing official launcher artwork:\n  " + "\n  ".join(str(p) for p in paths))


def _full_master() -> Path:
    return _first_existing(
        [
            PLAY / "ic_launcher_1024.png",
            REPO / "5min-ios-app" / "store" / "artwork" / "ic_launcher_1024.png",
            REPO / "5min-harmony-app" / "store" / "artwork" / "ic_launcher_1024.png",
            REPO / "5min-ios-app" / "FiveMin" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png",
        ]
    )


def _foreground_master() -> Path:
    return _first_existing(
        [
            PLAY / "ic_launcher_foreground_1080.png",
            REPO / "5min-ios-app" / "store" / "artwork" / "ic_launcher_foreground_1080.png",
            REPO / "5min-harmony-app" / "store" / "artwork" / "ic_launcher_foreground_1080.png",
            REPO / "5min-harmony-app" / "AppScope" / "resources" / "base" / "media" / "foreground.png",
        ]
    )


def _wordmark() -> Path:
    return _first_existing(
        [
            REPO / "5min-ios-app" / "FiveMin" / "Assets.xcassets" / "Logo.imageset" / "logo.png",
            REPO / "5min-harmony-app" / "entry" / "src" / "main" / "resources" / "base" / "media" / "logo.png",
            REPO / "5min-mp" / "assets" / "logo.png",
            RES / "drawable" / "logo.png",
        ]
    )


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
    full_src = _full_master()
    fg_src = _foreground_master()
    logo_src = _wordmark()

    full = Image.open(full_src).convert("RGBA")
    if full.size != (1024, 1024):
        full = full.resize((1024, 1024), Image.Resampling.LANCZOS)

    fg = Image.open(fg_src).convert("RGBA")
    if fg.size != (1080, 1080):
        # Keep transparent padding; scale to adaptive foreground canvas.
        fg = fg.resize((1080, 1080), Image.Resampling.LANCZOS)

    # Refresh store artwork only when sourced from another end (avoid recompress churn).
    PLAY.mkdir(parents=True, exist_ok=True)
    if full_src.resolve() != (PLAY / "ic_launcher_1024.png").resolve():
        save_png(full, PLAY / "ic_launcher_1024.png")
        save_png(full.resize((512, 512), Image.Resampling.LANCZOS), PLAY / "ic_launcher_512.png")
    elif not (PLAY / "ic_launcher_512.png").is_file():
        save_png(full.resize((512, 512), Image.Resampling.LANCZOS), PLAY / "ic_launcher_512.png")
    if fg_src.resolve() != (PLAY / "ic_launcher_foreground_1080.png").resolve():
        save_png(fg, PLAY / "ic_launcher_foreground_1080.png")

    # Adaptive foreground: official PNG (API 26+). Drop hand-drawn vector drift.
    fg_xml = RES / "drawable" / "ic_launcher_foreground.xml"
    if fg_xml.exists():
        fg_xml.unlink()
    nodpi = RES / "drawable-nodpi"
    nodpi.mkdir(parents=True, exist_ok=True)
    if fg_src.resolve() == (PLAY / "ic_launcher_foreground_1080.png").resolve() and fg.size == (1080, 1080):
        shutil.copyfile(fg_src, nodpi / "ic_launcher_foreground.png")
    else:
        save_png(fg, nodpi / "ic_launcher_foreground.png")

    # Legacy mipmaps (pre-26 / fallback)
    for folder, px in LEGACY.items():
        square = full.resize((px, px), Image.Resampling.LANCZOS)
        save_png(square, RES / folder / "ic_launcher.png")
        save_png(draw_round_mask(square), RES / folder / "ic_launcher_round.png")

    # In-app wordmark — same bytes as iOS / Harmony / MP
    shutil.copyfile(logo_src, RES / "drawable" / "logo.png")

    print("OK — Android icons synced to official artwork")
    print(f"  full ← {full_src.relative_to(REPO)}")
    print(f"  fg   ← {fg_src.relative_to(REPO)}")
    print(f"  logo ← {logo_src.relative_to(REPO)}")
    for p in sorted(PLAY.glob("ic_launcher_*.png")):
        print(f"  {p.relative_to(ROOT)}")
    print("  drawable-nodpi/ic_launcher_foreground.png")
    print("  drawable/logo.png")
    for density in LEGACY:
        print(f"  {density}/ic_launcher.png + ic_launcher_round.png")


if __name__ == "__main__":
    main()
