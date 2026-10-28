#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)"

APP="build/Brief.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH/Brief" "$APP/Contents/MacOS/Brief"
cp Info.plist "$APP/Contents/Info.plist"
# Sparkle compares CFBundleVersion, so it follows the release version.
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Frameworks"
ditto "$BIN_PATH/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
cp Resources/Assets.car Resources/AppIcon.icns "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Developer ID + hardened runtime so the app can be notarized; falls back to
# ad-hoc ("-") on machines without the certificate.
IDENTITY="${BRIEF_SIGN_IDENTITY:-Developer ID Application: Yannick Pulver (337L47P9N7)}"
if ! security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
  IDENTITY="-"
fi
if [ "$IDENTITY" = "-" ]; then
  SIGN=(codesign --force -s -)
else
  SIGN=(codesign --force --options runtime --timestamp -s "$IDENTITY")
fi
# Sparkle's helpers first, inside out, then the framework, then the app.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
"${SIGN[@]}" "$SPARKLE/XPCServices/Installer.xpc"
"${SIGN[@]}" --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
"${SIGN[@]}" "$SPARKLE/Autoupdate"
"${SIGN[@]}" "$SPARKLE/Updater.app"
"${SIGN[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
"${SIGN[@]}" --entitlements Brief.entitlements "$APP"

echo
echo "Built $APP (signed: $IDENTITY)"
echo "open build/Brief.app"
