#!/usr/bin/env bash
#
# Package the SwiftPM executable into a proper menu-bar .app bundle.
# Produces ./dist/Copilot Credits.app (LSUIElement => no Dock icon).
#
set -euo pipefail

APP_NAME="Copilot Credits"
BUNDLE_ID="com.local.copilotcreditsmenubar"
EXECUTABLE="CopilotCreditsMenuBar"
CONFIG="release"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# Use the Xcode toolchain via xcrun so the compiler matches the macOS SDK.
# (A standalone swiftly/swift.org toolchain on PATH may not match the SDK.)
# Build a universal binary so the .app runs on both Apple Silicon and Intel Macs.
ARCHS="--arch arm64 --arch x86_64"
echo "Building ($CONFIG, universal arm64+x86_64) with the Xcode toolchain…"
xcrun swift build -c "$CONFIG" $ARCHS

BIN_DIR="$(xcrun swift build -c "$CONFIG" $ARCHS --show-bin-path)"
APP_DIR="$ROOT/dist/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN_DIR/$EXECUTABLE" "$MACOS_DIR/$EXECUTABLE"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${EXECUTABLE}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so the app launches without Gatekeeper friction.
codesign --force --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "Built: $APP_DIR"
echo "Run:   open \"$APP_DIR\""
echo "Tip:   drag it into /Applications and add to Login Items to run at startup."
