#!/usr/bin/env bash
# Usage: ./release.sh 1.0.0
# Builds, notarizes, staples, and zips Brief.app for distribution.
# One-time setup: xcrun notarytool store-credentials brief \
#   --apple-id <apple-id> --team-id 337L47P9N7 --password <app-specific-password>
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?usage: ./release.sh <version>}"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Info.plist
./build.sh

ZIP="build/Brief-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/Brief.app "$ZIP"

# CI passes credentials via env (GitHub secrets); locally a keychain
# profile from `xcrun notarytool store-credentials brief` is used.
if [ -n "${NOTARY_APPLE_ID:-}" ]; then
  xcrun notarytool submit "$ZIP" --wait \
    --apple-id "$NOTARY_APPLE_ID" \
    --team-id "$NOTARY_TEAM_ID" \
    --password "$NOTARY_PASSWORD"
else
  xcrun notarytool submit "$ZIP" --keychain-profile brief --wait
fi
xcrun stapler staple build/Brief.app

# Re-zip so the download contains the stapled ticket.
rm -f "$ZIP"
ditto -c -k --keepParent build/Brief.app "$ZIP"

echo
echo "Release artifact: $ZIP"
shasum -a 256 "$ZIP"
