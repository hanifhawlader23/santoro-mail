#!/bin/bash
# Compila Santoro Mail.app y la instala en ~/Applications (sin Xcode abierto, sin cuenta de Apple).
set -e
cd "$(dirname "$0")"
OUT="$HOME/Applications/Santoro Mail.app"
B=build/SantoroMail.app
rm -rf build && mkdir -p "$B/Contents/MacOS" "$B/Contents/Resources"
swiftc -O main.swift -o "$B/Contents/MacOS/SantoroMail" -framework Cocoa -framework WebKit -framework UserNotifications
iconutil -c icns AppIcon.iconset -o "$B/Contents/Resources/AppIcon.icns"
cat > "$B/Contents/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
 <key>CFBundleName</key><string>Santoro Mail</string>
 <key>CFBundleDisplayName</key><string>Santoro Mail</string>
 <key>CFBundleIdentifier</key><string>com.hanifhawlader.santoromail</string>
 <key>CFBundleExecutable</key><string>SantoroMail</string>
 <key>CFBundleIconFile</key><string>AppIcon</string>
 <key>CFBundlePackageType</key><string>APPL</string>
 <key>CFBundleShortVersionString</key><string>1.0</string>
 <key>CFBundleVersion</key><string>1</string>
 <key>LSMinimumSystemVersion</key><string>12.0</string>
 <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
 <key>NSHighResolutionCapable</key><true/>
 <key>NSHumanReadableCopyright</key><string>Santoro · Hanif Hawlader</string>
</dict></plist>
PL
codesign --force --deep -s - "$B"
mkdir -p "$HOME/Applications"
rm -rf "$OUT" && cp -R "$B" "$OUT"
echo "OK → $OUT"
