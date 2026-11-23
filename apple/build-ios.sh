#!/bin/bash
# Santoro Mail para iPhone: compila con tu Apple ID (equipo personal) y la instala en el iPhone conectado.
# Uso: ./build-ios.sh TEAMID
set -e
cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:$PATH"
TEAM="$1"
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate --quiet
xcodebuild -project SantoroMail.xcodeproj -scheme SantoroMail-iOS -configuration Release -derivedDataPath build-ios \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates -allowProvisioningDeviceRegistration DEVELOPMENT_TEAM="$TEAM" -quiet build
APP="build-ios/Build/Products/Release-iphoneos/SantoroMail.app"
DEV=$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && /(available|connected)/ {for(i=1;i<=NF;i++) if($i ~ /^[0-9A-F]{8}-/) print $i}' | head -1)
[ -z "$DEV" ] && { echo "NO_IPHONE"; exit 2; }
xcrun devicectl device install app --device "$DEV" "$APP"
echo "OK ios $DEV"
