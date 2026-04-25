#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="FocusOverlay.app"
APP_DIR="$ROOT_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BIN_PATH="$ROOT_DIR/.build/debug/FocusOverlay"
APP_ICON_ICNS="$ROOT_DIR/Assets/AppIcon/AppIcon.icns"

cd "$ROOT_DIR"
swift build

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/FocusOverlay"
chmod +x "$MACOS_DIR/FocusOverlay"

if [ -f "$APP_ICON_ICNS" ]; then
  cp "$APP_ICON_ICNS" "$RESOURCES_DIR/AppIcon.icns"
fi

for bundle in "$ROOT_DIR"/.build/debug/*.bundle; do
  if [ -d "$bundle" ]; then
    ditto "$bundle" "$RESOURCES_DIR/$(basename "$bundle")"
  fi
done

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>FocusOverlay</string>
    <key>CFBundleExecutable</key>
    <string>FocusOverlay</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.focusoverlay</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>FocusOverlay</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "Built clickable app: $APP_DIR"
