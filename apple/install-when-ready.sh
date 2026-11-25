#!/bin/bash
# Espera a que el iPhone vuelva (misma Wi-Fi o cable) y le instala la última versión compilada.
APP="$(cd "$(dirname "$0")" && pwd)/build-ios/Build/Products/Release-iphoneos/SantoroMail.app"
DEV=00008150-001A239C1ED9401C
for i in $(seq 1 720); do
  if xcrun devicectl list devices 2>/dev/null | grep "$DEV" | grep -qE '[[:space:]](available|connected)[[:space:]]'; then
    xcrun devicectl device install app --device "$DEV" "$APP" && echo "INSTALLED $(date)" && exit 0
  fi
  sleep 30
done
