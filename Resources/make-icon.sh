#!/usr/bin/env bash
# Regenerates Assets.car and AppIcon.icns from glyph.svg + AppIcon.icon/icon.json.
# Only run after changing those. Needs Xcode (actool) and Google Chrome, which
# renders the glyph because it resolves the system font for the day number.
#
# Assets.car is what macOS 26+ uses; a plain .icns gets put on a gray plate at
# small sizes there. AppIcon.icns is the fallback for macOS 14/15.
set -euo pipefail
cd "$(dirname "$0")"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

printf '<body style="margin:0"><img src="file://%s/glyph.svg" width="1024" height="1024">' "$PWD" > "$TMP/glyph.html"
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --default-background-color=00000000 --window-size=1024,1024 \
  --screenshot="$PWD/AppIcon.icon/Assets/glyph.png" "file://$TMP/glyph.html" >/dev/null 2>&1

xcrun actool AppIcon.icon --compile "$TMP" --app-icon AppIcon --platform macosx \
  --minimum-deployment-target 14.0 --target-device mac \
  --output-partial-info-plist "$TMP/partial.plist" >/dev/null
cp "$TMP/Assets.car" "$TMP/AppIcon.icns" .
echo "Wrote Resources/Assets.car and Resources/AppIcon.icns"
