#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="WiFiConfigTool"
APP_DIR="/private/tmp/WiFiConfigToolBuild/${APP_NAME}.app"
ICONSET_DIR="/private/tmp/WiFiConfigToolBuild/${APP_NAME}.iconset"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BINARY_PATH="$ROOT_DIR/.build/release/$APP_NAME"

swift build -c release --package-path "$ROOT_DIR" >&2

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BINARY_PATH" "$MACOS_DIR/$APP_NAME"

rm -rf "$ICONSET_DIR"
/usr/bin/env swift "$ROOT_DIR/scripts/generate_app_icon.swift" "$ICONSET_DIR"
if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>WiFiConfigTool</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>local.yuhao.WiFiConfigTool</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Wi-Fi 配置工具</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.5.0</string>
    <key>CFBundleVersion</key>
    <string>5</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSLocationUsageDescription</key>
    <string>用于读取当前 Wi-Fi 名称，以便保存和自动匹配网络配置。</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>用于读取当前 Wi-Fi 名称，以便保存和自动匹配网络配置。</string>
</dict>
</plist>
PLIST

if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$APP_DIR"
    xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
    xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_DIR" 2>/dev/null || true
fi

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"
