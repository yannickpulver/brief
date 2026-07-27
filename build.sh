#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)"

APP="build/Brief.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp "$BIN_PATH/Brief" "$APP/Contents/MacOS/Brief"
cp Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Developer ID + hardened runtime so the app can be notarized; falls back to
# ad-hoc ("-") on machines without the certificate.
IDENTITY="${BRIEF_SIGN_IDENTITY:-Developer ID Application: Yannick Pulver (337L47P9N7)}"
if ! security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
  IDENTITY="-"
fi
if [ "$IDENTITY" = "-" ]; then
  codesign --force -s - "$APP"
else
  codesign --force --options runtime --timestamp \
    --entitlements Brief.entitlements -s "$IDENTITY" "$APP"
fi

echo
echo "Built $APP (signed: $IDENTITY)"
echo "open build/Brief.app"
