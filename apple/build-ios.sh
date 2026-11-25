#!/bin/bash
# Santoro Mail para iPhone: compila con tu Apple ID (equipo personal) y la instala en el iPhone conectado.
# Uso: ./build-ios.sh TEAMID
set -e
cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:$PATH"
TEAM="$1"
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate --quiet
DEV=$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && /(available|connected)/ {for(i=1;i<=NF;i++) if($i ~ /^[0-9A-F]{8}-/) print $i}' | head -1)
[ -z "$DEV" ] && { echo "NO_IPHONE"; exit 2; }
# el iPhone concreto como destino: así Xcode lo registra en tu equipo personal y crea el perfil
UDID=$(xcrun xctrace list devices 2>/dev/null | grep -v Simulator | grep -i iphone | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' | head -1)
xcodebuild -project SantoroMail.xcodeproj -scheme SantoroMail-iOS -configuration Release -derivedDataPath build-ios \
  -destination "id=${UDID:-$DEV}" -allowProvisioningUpdates -allowProvisioningDeviceRegistration DEVELOPMENT_TEAM="$TEAM" -quiet build
APP="build-ios/Build/Products/Release-iphoneos/SantoroMail.app"
xcrun devicectl device install app --device "$DEV" "$APP"
echo "OK ios $DEV"
