#!/usr/bin/env bash
# Capture Play / AppGallery phone screenshots: idle → running → done.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/store/artwork/screenshots"
PKG="chat.fivemin.app"
ACTIVITY="$PKG/.MainActivity"
SCENES=(idle running done)
ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"

die() { echo "error: $*" >&2; exit 1; }
[[ -x "$ADB" ]] || die "adb not found at $ADB"
"$ADB" devices | awk 'NR>1 && $2=="device"{found=1} END{exit found?0:1}' \
  || die "no Android device/emulator (adb devices)"

echo "==> Building debug APK"
"$ROOT/scripts/assemble-debug.sh" >/tmp/5min-android-screenshot-build.log \
  || { tail -40 /tmp/5min-android-screenshot-build.log; die "assembleDebug failed"; }

APK="$(ls -1 "$ROOT"/app/build/outputs/apk/debug/*.apk | head -1)"
[[ -f "$APK" ]] || die "missing debug apk"

mkdir -p "$OUT"
echo "==> Installing $APK"
"$ADB" uninstall "$PKG" >/dev/null 2>&1 || true
"$ADB" install -r "$APK" >/dev/null
# Quiet demo status bar-ish: dismiss lock / stay awake
"$ADB" shell settings put global stay_on_while_plugged_in 3 >/dev/null 2>&1 || true
"$ADB" shell wm dismiss-keyguard >/dev/null 2>&1 || true

capture() {
  local scene="$1"
  local file="$OUT/01_${scene}.png"
  case "$scene" in
    idle) file="$OUT/01_idle_start.png" ;;
    running) file="$OUT/02_running.png" ;;
    done) file="$OUT/03_done_restart.png" ;;
  esac
  "$ADB" shell am force-stop "$PKG" >/dev/null 2>&1 || true
  "$ADB" shell am start -n "$ACTIVITY" --es FIVEMIN_SCREENSHOT "$scene" >/dev/null
  case "$scene" in
    running|warn) sleep 3.5 ;;
    done) sleep 3.0 ;;
    *) sleep 2.5 ;;
  esac
  # Drop SystemUI ANR overlays common on cold emulators, then capture promptly.
  "$ADB" shell pkill -f com.android.systemui >/dev/null 2>&1 || true
  sleep 1.2
  "$ADB" exec-out screencap -p >"$file"
  local bytes
  bytes="$(wc -c <"$file" | tr -d ' ')"
  if [[ "$bytes" -lt 40000 ]]; then
    die "screenshot looks blank: $file (${bytes}B)"
  fi
  echo "  $file  (${bytes}B)"
}

echo "==> Capturing"
for scene in "${SCENES[@]}"; do
  capture "$scene"
done
"$ADB" shell am force-stop "$PKG" >/dev/null 2>&1 || true
echo "==> Done → $OUT"
