#!/usr/bin/env bash
# Capture HarmonyOS store screenshots (idle / running / done) via hdc.
# Requires a booted emulator or device with a debug-signed HAP installed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/store/artwork/screenshots"
BUNDLE="chat.5min.app"
ABILITY="EntryAbility"
HDC="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
SCENES=(idle running done)

die() { echo "error: $*" >&2; exit 1; }
[[ -x "$HDC" ]] || die "hdc not found: $HDC"

targets="$("$HDC" list targets 2>/dev/null | awk 'NF && $0 !~ /Empty/ {print; exit}')"
[[ -n "$targets" ]] || die "no Harmony device (hdc list targets). Start DevEco emulator first."

mkdir -p "$OUT"

capture() {
  local scene="$1"
  local file
  case "$scene" in
    idle|home) file="$OUT/01_idle_start.png" ;;
    running) file="$OUT/02_running.png" ;;
    done) file="$OUT/03_done_restart.png" ;;
    *) file="$OUT/${scene}.png" ;;
  esac
  "$HDC" shell aa force-stop "$BUNDLE" >/dev/null 2>&1 || true
  "$HDC" shell aa start -a "$ABILITY" -b "$BUNDLE" --ps FIVEMIN_SCREENSHOT "$scene" >/dev/null
  case "$scene" in
    running|warn) sleep 2.8 ;;
    done) sleep 2.2 ;;
    *) sleep 1.8 ;;
  esac
  "$HDC" shell snapshot_display -f /data/local/tmp/5min_shot.png >/dev/null 2>&1 \
    || "$HDC" shell uitest screenCap -p /data/local/tmp/5min_shot.png >/dev/null 2>&1 \
    || die "snapshot failed (try DevEco Device Manager screenshot)"
  "$HDC" file recv /data/local/tmp/5min_shot.png "$file" >/dev/null
  local bytes
  bytes="$(wc -c <"$file" | tr -d ' ')"
  if [[ "$bytes" -lt 40000 ]]; then
    die "screenshot looks blank: $file (${bytes}B)"
  fi
  echo "  $file  (${bytes}B)"
}

echo "==> Capturing on $targets"
for scene in "${SCENES[@]}"; do
  capture "$scene"
done
"$HDC" shell aa force-stop "$BUNDLE" >/dev/null 2>&1 || true
echo "==> Done → $OUT"
