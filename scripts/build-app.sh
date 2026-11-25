#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
VERSION=${C2C_VERSION:-1.0.1}
swift build -c release --product C2C
BIN_DIR=$(swift build -c release --show-bin-path)
BINARY="$BIN_DIR/C2C"
APP="$ROOT/build/C2C.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/C2C"
cp Resources/COPYING Resources/NOTICE "$APP/Contents/Resources/"
ICONSET="$ROOT/.build/C2C.iconset"
swiftc -swift-version 6 Sources/C2CApp/C2CIcon.swift scripts/IconGenerator/main.swift -o "$ROOT/.build/generate-c2c-icon"
"$ROOT/.build/generate-c2c-icon" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/C2C.icns"
cp "$ICONSET/icon_512x512@2x.png" Resources/C2C-icon.png
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDisplayName</key><string>C2C</string>
<key>CFBundleExecutable</key><string>C2C</string>
<key>CFBundleIdentifier</key><string>com.c2c.clipboard</string>
<key>CFBundleName</key><string>C2C</string>
<key>CFBundleIconFile</key><string>C2C.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 C2C contributors. GPLv3.</string>
</dict></plist>
PLIST
if [ -n "${C2C_SIGNING_IDENTITY:-}" ]; then
  codesign --force --deep --options runtime --timestamp --sign "$C2C_SIGNING_IDENTITY" "$APP"
else
  codesign --force --deep --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"
echo "Built and verified $APP (version $VERSION)"
