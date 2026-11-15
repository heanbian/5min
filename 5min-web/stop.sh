#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$DIR/fivemin.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "未找到 $PID_FILE，服务可能未在运行"
  exit 0
fi

PID="$(tr -d '[:space:]' < "$PID_FILE" || true)"
if [[ -z "$PID" ]]; then
  rm -f "$PID_FILE"
  echo "pid 文件为空，已清理"
  exit 0
fi

if kill -0 "$PID" 2>/dev/null; then
  kill "$PID" 2>/dev/null || true
  echo "已停止 pid=$PID"
else
  echo "进程不存在 pid=$PID，清理 pid 文件"
fi
rm -f "$PID_FILE"
