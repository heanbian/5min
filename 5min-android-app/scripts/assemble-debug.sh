#!/usr/bin/env bash
# Debug APK with JDK 25 LTS (Gradle 9.9 / AGP 9.5).
set -euo pipefail
cd "$(dirname "$0")/.."

pick_java() {
  local candidates=(
    "${JAVA_HOME:-}"
    "/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home"
    "/Library/Java/JavaVirtualMachines/jdk-25.jdk/Contents/Home"
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home"
    "/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home"
  )
  local home
  for home in "${candidates[@]}"; do
    [[ -z "$home" || ! -x "$home/bin/java" ]] && continue
    local ver
    ver="$("$home/bin/java" -version 2>&1 | head -1 || true)"
    if echo "$ver" | grep -Eq 'version "(25|26|27|21|22|23|24)[\".]'; then
      echo "$home"
      return 0
    fi
  done
  return 1
}

JAVA_HOME="$(pick_java)" || {
  echo "需要 JDK 25 LTS（或 ≥21）。请安装 Temurin 25，或使用 Android Studio 自带 JBR。"
  exit 1
}
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"
# Silence JDK 25 restricted JNI warnings from Gradle native-platform.
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }--enable-native-access=ALL-UNNAMED"
echo "Using JAVA_HOME=$JAVA_HOME"
./gradlew :app:assembleDebug "$@"
echo
ls -la app/build/outputs/apk/debug/5min-android-app-*.apk 2>/dev/null || \
  ls -la app/build/outputs/apk/debug/*.apk 2>/dev/null || true
