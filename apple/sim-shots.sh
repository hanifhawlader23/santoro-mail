#!/bin/bash
# Compila para el simulador, abre la app con datos de ejemplo y hace capturas (solo para revisar el diseño).
# Uso: ./sim-shots.sh nombre [-menu|-compose|-settings]
cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:$PATH"
OUT="$HOME/SantoroMail-app/shots"; mkdir -p "$OUT"
if [ "$1" = "build" ]; then
  xcodegen generate --quiet
  xcodebuild -project SantoroMail.xcodeproj -scheme SantoroMail-iOS -configuration Debug -derivedDataPath build-sim \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build > "$OUT/build.log" 2>&1 || { grep -E ': error:' "$OUT/build.log" | sed 's/.*Shared\///' | sort -u | head -25; exit 1; }
  xcrun simctl install booted build-sim/Build/Products/Debug-iphonesimulator/SantoroMail.app
  echo BUILD_OK; exit 0
fi
NAME="$1"; shift
xcrun simctl terminate booted com.hanifhawlader.santoromail 2>/dev/null
xcrun simctl launch booted com.hanifhawlader.santoromail -preview "$@" >/dev/null
sleep "${WAIT:-5}"
xcrun simctl io booted screenshot "$OUT/$NAME.png" >/dev/null 2>&1 && echo "$OUT/$NAME.png"
