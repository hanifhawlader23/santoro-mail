#!/bin/bash
# Santoro Mail nativa para Mac → ~/Applications/Santoro Mail.app
set -e
cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:$PATH"
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate --quiet
xcodebuild -project SantoroMail.xcodeproj -scheme SantoroMail-macOS -configuration Release -derivedDataPath build -quiet build
pkill -x "Santoro Mail" 2>/dev/null || true; pkill -x SantoroMail 2>/dev/null || true
rm -rf "$HOME/Applications/Santoro Mail.app"
cp -R "build/Build/Products/Release/Santoro Mail.app" "$HOME/Applications/"
echo "OK mac"
