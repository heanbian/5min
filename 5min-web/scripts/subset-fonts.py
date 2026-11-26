#!/usr/bin/env python3
"""Subset Noto Sans SC to glyphs used by site HTML + locale packs."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FONTS = ROOT / "public" / "fonts"
PACKS = ROOT / "public" / "js" / "i18n" / "packs"
HTML_DIR = ROOT / "public"

# Keep common CJK punctuation / fullwidth digits even if unused in packs.
EXTRA = (
    "，。、；：？！「」『』（）【】《》—…·￥％％℃°±×÷"
    "0123456789"
    "－～｜／＼＠＃＊＆"
)

CJK_RE = re.compile(
    r"["
    r"\u2E80-\u2FFF"
    r"\u3000-\u30FF"
    r"\u31F0-\u4DBF"
    r"\u4E00-\u9FFF"
    r"\uF900-\uFAFF"
    r"\uFE10-\uFE1F"
    r"\uFE30-\uFE4F"
    r"\uFF00-\uFFEF"
    r"]"
)


def collect_text() -> str:
    chunks: list[str] = [EXTRA]
    for path in PACKS.glob("*.js"):
        chunks.append(path.read_text(encoding="utf-8"))
    for path in HTML_DIR.rglob("*.html"):
        chunks.append(path.read_text(encoding="utf-8"))
    css = HTML_DIR / "css"
    if css.is_dir():
        for path in css.glob("*.css"):
            chunks.append(path.read_text(encoding="utf-8"))
    return "".join(chunks)


def main() -> int:
    try:
        from fontTools.subset import main as subset_main
    except ImportError:
        print("fontTools missing; run: .tools-venv/bin/pip install fonttools brotli", file=sys.stderr)
        return 1

    text = collect_text()
    chars = sorted(set(CJK_RE.findall(text)))
    if not chars:
        print("no CJK characters found", file=sys.stderr)
        return 1
    unicodes = ",".join(f"U+{ord(c):04X}" for c in chars)
    print(f"subsetting to {len(chars)} CJK codepoints")

    for name in ("NotoSansSC-Regular.woff2", "NotoSansSC-Bold.woff2"):
        src = FONTS / name
        if not src.is_file():
            print(f"skip missing {src}", file=sys.stderr)
            continue
        tmp = FONTS / (name + ".subset.tmp")
        argv = [
            str(src),
            f"--output-file={tmp}",
            f"--unicodes={unicodes}",
            "--flavor=woff2",
            "--layout-features=*",
            "--name-IDs=*",
            "--name-legacy",
            "--name-languages=*",
            "--notdef-outline",
            "--recommended-glyphs",
            "--no-subset-tables+=FFTM",
        ]
        print(" ", name, "…")
        subset_main(argv)
        before = src.stat().st_size
        tmp.replace(src)
        after = src.stat().st_size
        print(f"  {name}: {before // 1024}KB → {after // 1024}KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
