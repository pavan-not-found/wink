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
# Assemble and sign outside the repo: iCloud-synced folders (Desktop, Documents)
# add Finder attributes to bundles, and codesign refuses to sign those.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/wink-build.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/Wink.app"

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
"$ARM" --iconset "$WORK/AppIcon.iconset"
iconutil -c icns "$WORK/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp bin/wink "$APP/Contents/Resources/wink" && chmod +x "$APP/Contents/Resources/wink"

echo "→ Signing ($SIGN_ID)"
xattr -cr "$APP"
if [[ "$SIGN_ID" == "-" ]]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
fi
codesign --verify --strict "$APP"

echo "→ Packaging"
ditto -c -k --norsrc --keepParent "$APP" "$WORK/Wink-$VERSION.zip"

STAGE="$WORK/dmg"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Wink.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Wink" -srcfolder "$STAGE" -ov -format UDZO "$WORK/Wink-$VERSION.dmg" >/dev/null

cp "$WORK/Wink-$VERSION.zip" "$WORK/Wink-$VERSION.dmg" dist/
ditto "$APP" dist/Wink.app

# Unversioned copies so releases/latest/download/Wink.dmg always works.
cp "dist/Wink-$VERSION.zip" dist/Wink.zip
cp "dist/Wink-$VERSION.dmg" dist/Wink.dmg

(cd dist && shasum -a 256 "Wink-$VERSION.zip" "Wink-$VERSION.dmg" Wink.zip Wink.dmg | tee SHA256SUMS.txt)
echo "✓ dist/Wink.app  dist/Wink-$VERSION.zip  dist/Wink-$VERSION.dmg"
