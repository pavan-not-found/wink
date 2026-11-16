#!/usr/bin/env bash
# Notarize a Developer ID–signed build so macOS opens it without any warning.
# Needs an Apple Developer account ($99/year) and, once:
#   xcrun notarytool store-credentials wink --apple-id you@example.com --team-id TEAMID
# Then:
#   SIGN_ID="Developer ID Application: Your Name (TEAMID)" scripts/build.sh
#   scripts/notarize.sh
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(cat VERSION)"
PROFILE="${NOTARY_PROFILE:-wink}"

for f in "dist/Wink-$VERSION.zip" "dist/Wink-$VERSION.dmg"; do
  echo "→ Notarizing $f"
  xcrun notarytool submit "$f" --keychain-profile "$PROFILE" --wait
done
xcrun stapler staple dist/Wink.app
xcrun stapler staple "dist/Wink-$VERSION.dmg"
# Re-zip so the zip carries the stapled app.
rm -f "dist/Wink-$VERSION.zip" && ditto -c -k --norsrc --keepParent dist/Wink.app "dist/Wink-$VERSION.zip"
cp "dist/Wink-$VERSION.zip" dist/Wink.zip && cp "dist/Wink-$VERSION.dmg" dist/Wink.dmg
spctl --assess --type execute --verbose dist/Wink.app
echo "✓ Notarized"
