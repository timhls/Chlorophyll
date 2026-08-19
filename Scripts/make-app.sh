#!/bin/bash
# Assembles the Chlorophyll.app bundle from a swift-build product.
set -euo pipefail

CONFIG="release"
while getopts "c:" opt; do
  case $opt in
    c) CONFIG="$OPTARG" ;;
    *) echo "usage: $0 [-c debug|release]" >&2; exit 1 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Chlorophyll"
APP="$ROOT/build/$APP_NAME.app"
MACOS_DIR="$APP/Contents/MacOS"
RESOURCES_DIR="$APP/Contents/Resources"

# SPM binary location varies by toolchain layout.
BIN_CANDIDATES=(
  "$ROOT/.build/$CONFIG/ChlorophyllApp"
  "$ROOT/.build/arm64-apple-macosx/$CONFIG/ChlorophyllApp"
  "$ROOT/.build/$CONFIG/apple/Products/ChlorophyllApp"
)
BIN=""
for candidate in "${BIN_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    BIN="$candidate"
    break
  fi
done
if [[ -z "$BIN" ]]; then
  echo "error: ChlorophyllApp binary not found; run 'swift build -c $CONFIG' first" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN" "$MACOS_DIR/$APP_NAME"

VERSION="$(git -C "$ROOT" describe --tags --always --dirty 2>/dev/null || echo 0.1.0)"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>Chlorophyll</string>
	<key>CFBundleIdentifier</key>
	<string>org.chlorophyll.Chlorophyll</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Chlorophyll</string>
	<key>CFBundleDisplayName</key>
	<string>Chlorophyll</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.utilities</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || codesign --force --sign - "$APP"

echo "Assembled $APP"
