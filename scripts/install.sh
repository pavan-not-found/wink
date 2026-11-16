#!/usr/bin/env bash
# Installs the latest Wink into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/pavan-parallel/wink/main/scripts/install.sh | bash
#
# Wink isn't notarized yet, so a downloaded copy gets macOS's "unidentified developer"
# warning. This script removes the quarantine flag on the app it just downloaded,
# which is the same thing as right-clicking it and choosing Open.
set -euo pipefail

REPO="${WINK_REPO:-pavan-parallel/wink}"
echo "Finding the latest Wink release…"
URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -1 | cut -d'"' -f4)"
[ -n "$URL" ] || { echo "Couldn't find a release zip for $REPO." >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Downloading $URL"
curl -fsSL "$URL" -o "$TMP/Wink.zip"
ditto -x -k "$TMP/Wink.zip" "$TMP"

if pgrep -x Wink >/dev/null; then
  echo "Quitting the running copy…"
  osascript -e 'quit app "Wink"' >/dev/null 2>&1 || pkill -x Wink || true
  sleep 1
fi

rm -rf /Applications/Wink.app
mv "$TMP/Wink.app" /Applications/
xattr -dr com.apple.quarantine /Applications/Wink.app 2>/dev/null || true

# The command-line helper, if there's somewhere sensible to put it.
for dir in /opt/homebrew/bin /usr/local/bin; do
  if [ -w "$dir" ]; then
    curl -fsSL "https://raw.githubusercontent.com/$REPO/main/bin/wink" -o "$dir/wink" && chmod +x "$dir/wink" \
      && echo "Installed the 'wink' command to $dir"
    break
  fi
done

open /Applications/Wink.app
echo "Done. Look for the eye in your menu bar."
