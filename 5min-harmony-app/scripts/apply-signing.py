#!/usr/bin/env python3
"""Inject release signingConfigs into build-profile.json5 from signing.properties."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROPS = ROOT / "signing.properties"
PROFILE = ROOT / "build-profile.json5"


def load_props(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip()
    return out


def main() -> int:
    if not PROPS.exists():
        print(f"Missing {PROPS.name}. Copy signing.properties.example → signing.properties")
        return 1
    p = load_props(PROPS)
    required = (
        "name", "type", "storeFile", "storePassword", "keyAlias",
        "keyPassword", "certpath", "profile", "signAlg",
    )
    missing = [k for k in required if not p.get(k)]
    if missing:
        print("Missing keys:", ", ".join(missing))
        return 1

    if p["storePassword"] in ("CHANGE_ME", "") or p["keyPassword"] in ("CHANGE_ME", ""):
        print("请先在 signing.properties 中把 storePassword / keyPassword 改成真实密码。")
        return 1

    # hvigor 要求 build-profile 里的密码是 IDE 加密串（通常 ≥32）；明文会报 00303116。
    if len(p["storePassword"]) < 32 or len(p["keyPassword"]) < 32:
        print("错误：不能把明文密码直接写入 build-profile.json5（需 ≥32 的加密串）。")
        print("请改用 DevEco：File → Project Structure → Signing Configs")
        print("  取消 Automatically generate signature，填入 .p12/.cer/.p7b 与密码后 Apply。")
        print("IDE 会自动加密密码并写回 build-profile.json5，然后再执行 ./scripts/release.sh hap")
        return 1

    def abs_material(rel: str) -> str:
        path = Path(rel)
        if not path.is_absolute():
            path = (ROOT / path).resolve()
        if not path.is_file():
            print(f"缺少签名文件: {path}")
            print("请把 .p12 / .cer / .p7b 放到 signing/material/ 后再执行。")
            raise SystemExit(1)
        return str(path)

    store_file = abs_material(p["storeFile"])
    certpath = abs_material(p["certpath"])
    profile = abs_material(p["profile"])

    # json5-ish: strip comments / trailing commas for a tolerant parse
    text = PROFILE.read_text(encoding="utf-8")
    cleaned = re.sub(r"//.*?$", "", text, flags=re.M)
    cleaned = re.sub(r",\s*([}\]])", r"\1", cleaned)
    data = json.loads(cleaned)

    cfg = {
        "name": p["name"],
        "type": p["type"],
        "material": {
            "storeFile": store_file,
            "storePassword": p["storePassword"],
            "keyAlias": p["keyAlias"],
            "keyPassword": p["keyPassword"],
            "certpath": certpath,
            "profile": profile,
            "signAlg": p["signAlg"],
        },
    }
    data["app"]["signingConfigs"] = [cfg]
    # Point default product at this signing config
    for product in data["app"].get("products", []):
        if product.get("name") == "default":
            product["signingConfig"] = p["name"]

    PROFILE.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Updated {PROFILE.relative_to(ROOT)} with signingConfig '{p['name']}'")
    print("Note: build-profile now contains secrets locally — do not commit.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
