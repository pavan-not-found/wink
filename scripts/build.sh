#!/usr/bin/env bash
# Builds dist/Wink.app, dist/Wink-<version>.zip and dist/Wink-<version>.dmg
#
#   scripts/build.sh                 ad-hoc signed (fine for yourself and friends)
#   SIGN_ID="Developer ID Application: Your Name (TEAMID)" scripts/build.sh
#                                    signed for distribution (then run scripts/notarize.sh)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(cat VERSION)"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
BUNDLE_ID="${BUNDLE_ID:-app.wink.mac}"
SIGN_ID="${SIGN_ID:--}"
APP="dist/Wink.app"

echo "→ Building Wink $VERSION ($BUILD)"
rm -rf dist build/AppIcon.iconset
mkdir -p dist build

# Universal binary (Apple silicon + Intel), minimum macOS 14.
swift build -c release --arch arm64 --arch x86_64 2>&1 | grep -E "error|warning: .*Wink/" || true
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Wink"
[[ -x "$BIN" ]] || BIN=".build/out/Products/Release/Wink"
[[ -x "$BIN" ]] || BIN=".build/apple/Products/Release/Wink"
lipo -info "$BIN"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Wink"
ARM="$APP/Contents/MacOS/Wink"

sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" -e "s/__BUNDLE_ID__/$BUNDLE_ID/" \
  Resources/Info.plist > "$APP/Contents/Info.plist"

echo "→ Drawing the icon"
"$ARM" --iconset build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

echo "→ Signing ($SIGN_ID)"
if [[ "$SIGN_ID" == "-" ]]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
fi
codesign --verify --strict "$APP"

echo "→ Packaging"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/Wink-$VERSION.zip"

STAGE="build/dmg"
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Wink" -srcfolder "$STAGE" -ov -format UDZO "dist/Wink-$VERSION.dmg" >/dev/null

shasum -a 256 "dist/Wink-$VERSION.zip" "dist/Wink-$VERSION.dmg" | tee dist/SHA256SUMS.txt
echo "✓ dist/Wink.app  dist/Wink-$VERSION.zip  dist/Wink-$VERSION.dmg"
