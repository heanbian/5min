#!/usr/bin/env bash
# Local static preview for 5min (ES modules need http(s)).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${1:-${PORT:-8080}}"

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "Invalid port: $PORT (use 1–65535)" >&2
  exit 1
fi

cd "$ROOT"
echo "Serving $ROOT at http://localhost:${PORT}/"
exec npx --yes serve -l "$PORT" .
