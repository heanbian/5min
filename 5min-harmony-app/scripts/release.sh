#!/usr/bin/env bash
# Build signed release HAP/APP and rename to 5min-harmony-app-{versionName}.*
set -euo pipefail
cd "$(dirname "$0")/.."

DEVECO="${DEVECO_HOME:-/Applications/DevEco-Studio.app/Contents}"
HVIGORW="${DEVECO}/tools/hvigor/bin/hvigorw"
OHPM="${DEVECO}/tools/ohpm/bin/ohpm"
NODE="${DEVECO}/tools/node/bin/node"

# hvigor 需要有效的 DEVECO_SDK_HOME（指向 …/sdk，内含 default/）
if [[ -z "${DEVECO_SDK_HOME:-}" ]]; then
  if [[ -d "${DEVECO}/sdk/default" ]]; then
    export DEVECO_SDK_HOME="${DEVECO}/sdk"
  elif [[ -d "${HOME}/Library/Huawei/Sdk/default" ]]; then
    export DEVECO_SDK_HOME="${HOME}/Library/Huawei/Sdk"
  fi
fi
if [[ -z "${DEVECO_SDK_HOME:-}" || ! -d "${DEVECO_SDK_HOME}/default" ]]; then
  echo "无效的 DEVECO_SDK_HOME=${DEVECO_SDK_HOME:-<unset>}"
  echo "请安装 DevEco Studio SDK，或 export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk"
  exit 1
fi
export PATH="${DEVECO}/tools/node/bin:${DEVECO}/tools/ohpm/bin:${PATH}"

if [[ ! -x "$HVIGORW" ]]; then
  echo "未找到 DevEco hvigorw：$HVIGORW"
  echo "请安装 DevEco Studio 26+，或设置 DEVECO_HOME。"
  exit 1
fi

echo "DEVECO_SDK_HOME=$DEVECO_SDK_HOME"

VERSION="$(python3 - <<'PY'
import json,re
from pathlib import Path
text=Path('AppScope/app.json5').read_text(encoding='utf-8')
text=re.sub(r'//.*?$','',text,flags=re.M)
text=re.sub(r',\s*([}\]])',r'\1',text)
print(json.loads(text)['app']['versionName'])
PY
)"
echo "versionName=$VERSION"

if [[ -x "$OHPM" ]]; then
  "$OHPM" install
else
  echo "warn: ohpm not found, skip install"
fi

TARGET="${1:-hap}"
case "$TARGET" in
  hap)
    "$HVIGORW" --stop-daemon >/dev/null 2>&1 || true
    "$HVIGORW" assembleHap --mode module -p module=entry@default -p product=default -p buildMode=release --no-daemon
    # 优先取已签名产物，避免误拷 unsigned
    SRC="$(find entry/build -type f -name '*-signed.hap' 2>/dev/null | head -1 || true)"
    if [[ -z "${SRC:-}" ]]; then
      SRC="$(find entry/build -type f -name '*.hap' ! -name '*-unsigned.hap' 2>/dev/null | head -1 || true)"
    fi
    OUT="store/release/5min-harmony-app-${VERSION}.hap"
    ;;
  app|bundle)
    "$HVIGORW" --stop-daemon >/dev/null 2>&1 || true
    "$HVIGORW" assembleApp -p product=default -p buildMode=release --no-daemon
    SRC="$(find build/outputs -type f -name '*-signed.app' 2>/dev/null | head -1 || true)"
    if [[ -z "${SRC:-}" ]]; then
      SRC="$(find build/outputs -type f -name '*.app' ! -name '*-unsigned.app' 2>/dev/null | head -1 || true)"
    fi
    OUT="store/release/5min-harmony-app-${VERSION}.app"
    ;;
  *)
    echo "用法: $0 [hap|app]"
    exit 1
    ;;
esac

if [[ -z "${SRC:-}" || ! -f "$SRC" ]]; then
  echo "未找到构建产物，请检查 DevEco 同步 / 签名配置。"
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
cp -f "$SRC" "$OUT"
echo
echo "产物：$OUT"
ls -la "$OUT"
