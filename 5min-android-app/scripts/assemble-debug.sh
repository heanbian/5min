#!/usr/bin/env bash
# Debug APK with a Gradle-compatible JDK (17/21), not JDK 25+.
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
    if echo "$ver" | grep -Eq 'version "(17|18|19|20|21)[\".]'; then
      echo "$home"
      return 0
    fi
  done
  return 1
}

JAVA_HOME="$(pick_java)" || {
  echo "需要 JDK 17 或 21。当前默认 JDK 过新（如 25）会导致 Gradle 报 25.0.x 失败。"
  exit 1
}
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"
echo "Using JAVA_HOME=$JAVA_HOME"
./gradlew :app:assembleDebug "$@"
echo
ls -la app/build/outputs/apk/debug/5min-android-app-*.apk 2>/dev/null || \
  ls -la app/build/outputs/apk/debug/*.apk 2>/dev/null || true
