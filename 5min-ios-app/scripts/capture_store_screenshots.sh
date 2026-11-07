#!/usr/bin/env bash
# Capture App Store Connect required screenshots via headless simctl.
# Requires Xcode + iOS Simulator runtimes.
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/store/artwork/screenshots"
DERIVED="$ROOT/build/DerivedData"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/FiveMin.app"
BUNDLE_ID="chat.5min.app"

IPHONE_NAME="${IPHONE_NAME:-iPhone 17}"
IPAD_NAME="${IPAD_NAME:-iPad Pro 13-inch (M5)}"

SCENES=(home running warn records mine)

die() { echo "error: $*" >&2; exit 1; }

device_udid() {
  local name="$1"
  # Exact device-name match before the UDID (...). Avoids "iPhone 17" hitting "iPhone 17e".
  xcrun simctl list devices available \
    | awk -v n="$name" '
        {
          line = $0
          sub(/^[[:space:]]+/, "", line)
          # name is everything before " (UUID"
          if (match(line, / \([0-9A-Fa-f-]{36}\)/)) {
            dname = substr(line, 1, RSTART - 1)
            # Drop optional RAM suffix like " (16GB)" already part of name for iPad.
            if (dname == n || index(dname, n " (") == 1) {
              if (match(line, /\([0-9A-Fa-f-]{36}\)/)) {
                print substr(line, RSTART + 1, RLENGTH - 2)
                exit
              }
            }
          }
        }'
}

ensure_boot() {
  local udid="$1"
  local state
  state="$(xcrun simctl list devices | awk -v u="$udid" '$0 ~ u { if ($0 ~ /Booted/) print "Booted"; else print "Shutdown"; exit }')"
  if [[ "$state" != "Booted" ]]; then
    xcrun simctl boot "$udid"
  fi
  xcrun simctl bootstatus "$udid" -b >/dev/null
}

erase_and_install() {
  local udid="$1"
  xcrun simctl uninstall "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$udid" "$APP"
  # Clean, marketing-style status bar for store shots.
  xcrun simctl status_bar "$udid" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularMode active \
    --cellularBars 4 \
    --wifiMode active \
    --wifiBars 3 \
    --dataNetwork wifi >/dev/null 2>&1 || true
}

capture_device() {
  local udid="$1"
  local prefix="$2"
  mkdir -p "$OUT"
  for scene in "${SCENES[@]}"; do
    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    # simctl injects env vars prefixed with SIMCTL_CHILD_
    SIMCTL_CHILD_FIVEMIN_SCREENSHOT="$scene" \
      xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE_ID" >/dev/null
    # First-frame paint + deferred start() for running/warn (~0.4s) + ticker.
    case "$scene" in
      running|warn) sleep 2.8 ;;
      *) sleep 2.0 ;;
    esac
    local file="$OUT/${prefix}-${scene}.png"
    xcrun simctl io "$udid" screenshot "$file" >/dev/null
    local w h bytes
    w="$(sips -g pixelWidth "$file" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
    h="$(sips -g pixelHeight "$file" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
    bytes="$(wc -c <"$file" | tr -d ' ')"
    # Blank/white captures are typically tiny; fail the run so we don't upload junk.
    if [[ "$bytes" -lt 80000 ]]; then
      die "screenshot looks blank: $file (${bytes} bytes)"
    fi
    echo "  $file  (${w}x${h}, ${bytes}B)"
  done
}

echo "==> Building Debug for simulator"
xcodebuild \
  -project "$ROOT/FiveMin.xcodeproj" \
  -scheme FiveMin \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED" \
  build >/tmp/5min-screenshot-build.log \
  || { tail -40 /tmp/5min-screenshot-build.log; die "xcodebuild failed"; }

[[ -d "$APP" ]] || die "missing app at $APP"

IPHONE_UDID="$(device_udid "$IPHONE_NAME")"
IPAD_UDID="$(device_udid "$IPAD_NAME")"
[[ -n "$IPHONE_UDID" ]] || die "simulator not found: $IPHONE_NAME"
[[ -n "$IPAD_UDID" ]] || die "simulator not found: $IPAD_NAME"

echo "==> iPhone ($IPHONE_NAME / $IPHONE_UDID)"
# Full erase clears sticky SpringBoard permission alerts from earlier runs.
xcrun simctl shutdown "$IPHONE_UDID" >/dev/null 2>&1 || true
xcrun simctl erase "$IPHONE_UDID"
ensure_boot "$IPHONE_UDID"
erase_and_install "$IPHONE_UDID"
capture_device "$IPHONE_UDID" "iphone-medium"

echo "==> iPad ($IPAD_NAME / $IPAD_UDID)"
xcrun simctl shutdown "$IPAD_UDID" >/dev/null 2>&1 || true
xcrun simctl erase "$IPAD_UDID"
ensure_boot "$IPAD_UDID"
erase_and_install "$IPAD_UDID"
capture_device "$IPAD_UDID" "ipad13"

# Remove temp capture if present
rm -f "$OUT"/_tmp_*.png

echo "==> Done. Upload ASC:"
echo "  iPhone Dynamic Island medium: ${OUT}/iphone-medium-*.png"
echo "  iPad 13-inch:                 ${OUT}/ipad13-*.png"
