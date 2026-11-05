#!/usr/bin/env bash
# Archive + export IPA → store/release/5min-ios-app-{version}.ipa
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="${SCHEME:-FiveMin}"
PROJECT="FiveMin.xcodeproj"
CONFIG="Release"
ARCHIVE_PATH="build/FiveMin.xcarchive"
EXPORT_DIR="build/export"
OUT_DIR="store/release"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "未找到 xcodebuild。请安装 Xcode 并执行：sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' FiveMin/Info.plist 2>/dev/null || true)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' FiveMin/Info.plist 2>/dev/null || true)"
VERSION="${VERSION:-1.0.0}"
BUILD="${BUILD:-1}"
echo "version=$VERSION ($BUILD)"

if [[ ! -f ExportOptions.plist ]]; then
  echo "缺少 ExportOptions.plist。"
  echo "请：cp ExportOptions.plist.example ExportOptions.plist 并填写 teamID。"
  echo "或改用 Xcode：Product → Archive → Distribute App。"
  exit 1
fi

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
mkdir -p build "$OUT_DIR" signing/material

echo "→ Archive"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  clean archive \
  CODE_SIGN_STYLE=Automatic

echo "→ Export IPA"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist ExportOptions.plist

IPA_SRC="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' | head -1 || true)"
if [[ -z "${IPA_SRC:-}" || ! -f "$IPA_SRC" ]]; then
  echo "未找到 IPA，请检查签名 / ExportOptions.plist / Team。"
  exit 1
fi

OUT="$OUT_DIR/5min-ios-app-${VERSION}.ipa"
cp -f "$IPA_SRC" "$OUT"
echo
echo "产物：$OUT"
ls -la "$OUT"
echo "也可将 $ARCHIVE_PATH 用 Xcode Organizer / Transporter 上传。"
