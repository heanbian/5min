#!/usr/bin/env bash
# 后台启动：./fivemin-linux-x64 -d（写 fivemin.pid，配合 stop.sh）
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

BIN="${FIVEMIN_BIN:-$DIR/fivemin-linux-x64}"
if [[ ! -f "$BIN" ]]; then
  if [[ -f "$DIR/server.js" ]]; then
    exec node "$DIR/server.js" -d
  fi
  echo "找不到可执行文件: $BIN" >&2
  echo "请先 npm run build:pkg，或设置 FIVEMIN_BIN=路径；源码环境可直接 node server.js -d" >&2
  exit 1
fi
if [[ ! -f "$DIR/public/site.json" ]]; then
  echo "找不到同级 public/site.json: $DIR/public/site.json" >&2
  echo "请将 public 目录与可执行文件放在同一目录后再启动" >&2
  exit 1
fi
chmod +x "$BIN" 2>/dev/null || true
exec "$BIN" -d
