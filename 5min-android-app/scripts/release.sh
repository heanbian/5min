#!/usr/bin/env bash
# Build signed release AAB/APK with a Gradle-compatible JDK (17/21), not JDK 25+.
set -euo pipefail
cd "$(dirname "$0")/.."

pick_java() {
  local candidates=(
    "${JAVA_HOME:-}"
    "/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home"
    "/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home"
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  )
  local home
  for home in "${candidates[@]}"; do
    [[ -z "$home" || ! -x "$home/bin/java" ]] && continue
    local ver
    ver="$("$home/bin/java" -version 2>&1 | head -1 || true)"
    # Accept Java 17–21 only (Gradle 8.9 / AGP 8.7)
    if echo "$ver" | grep -Eq 'version "(17|18|19|20|21)[\".]'; then
      echo "$home"
      return 0
    fi
  done
  return 1
}

JAVA_HOME="$(pick_java)" || {
  echo "需要 JDK 17 或 21。当前默认 JDK 过新（如 25）会导致 Gradle 报 25.0.x 失败。"
  echo "请安装 Temurin/Oracle JDK 21，或用 Android Studio 自带 JBR。"
  exit 1
}
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"
echo "Using JAVA_HOME=$JAVA_HOME"
"$JAVA_HOME/bin/java" -version

TARGET="${1:-bundle}"
case "$TARGET" in
  bundle|aab) ./gradlew :app:bundleRelease ;;
  apk)        ./gradlew :app:assembleRelease ;;
  *)
    echo "用法: $0 [bundle|apk]"
    exit 1
    ;;
esac

echo
echo "产物："
ls -la app/build/outputs/bundle/release/5min-android-app-*.aab 2>/dev/null || true
ls -la app/build/outputs/apk/release/5min-android-app-*.apk 2>/dev/null || true
