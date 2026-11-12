#!/bin/bash
# Builds OnCue.app (Release, Apple Silicon) and packages it as a drag-to-Applications DMG.
#
# Unsigned by default (ad-hoc signature: runs on the Mac that built it, or after right-click > Open).
# For a DMG anyone can open, set:
#   SIGN_IDENTITY   "Developer ID Application: Your Name (TEAMID)"  (in the login keychain)
#   TEAM_ID         your 10-character team id
# and, to notarize, either an App Store Connect API key:
#   NOTARY_KEY_PATH  path to AuthKey_XXXX.p8,  NOTARY_KEY_ID,  NOTARY_ISSUER
# or an Apple ID with an app-specific password:
#   NOTARY_APPLE_ID,  NOTARY_PASSWORD   (TEAM_ID as above)
#
# Usage: scripts/package-dmg.sh [output folder]     (default: dist)
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="${1:-dist}"
BUILD="build/Release"
IDENTITY="${SIGN_IDENTITY:--}"
TEAM="${TEAM_ID:-}"

if ! [ -d OnCue.xcodeproj ]; then
  echo "Generating the Xcode project (needs XcodeGen: brew install xcodegen)"
  xcodegen generate
fi

VERSION=$(sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml | head -1)
BUILD_NUMBER=$(sed -n 's/.*CURRENT_PROJECT_VERSION: "\(.*\)"/\1/p' project.yml | head -1)
echo "OnCue $VERSION ($BUILD_NUMBER), signing identity: $IDENTITY"

SIGN_FLAGS=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$IDENTITY" "DEVELOPMENT_TEAM=$TEAM")
if [ "$IDENTITY" != "-" ]; then
  SIGN_FLAGS+=("OTHER_CODE_SIGN_FLAGS=--timestamp --options=runtime")
fi

xcodebuild -project OnCue.xcodeproj -scheme OnCue -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$BUILD" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO "${SIGN_FLAGS[@]}" \
  clean build | tee "$BUILD.log" | grep -E "error:|warning: .*deprecated|BUILD (SUCCEEDED|FAILED)" || true
grep -q "BUILD SUCCEEDED" "$BUILD.log" || { echo "Build failed, see $BUILD.log"; exit 1; }

APP="$BUILD/Build/Products/Release/OnCue.app"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv --verbose=2 "$APP" 2>&1 | grep -E "Authority|TeamIdentifier|Runtime|Signature" || true

# Disk image: the app and a link to Applications.
STAGE="$BUILD/dmg"
rm -rf "$STAGE" && mkdir -p "$STAGE" "$OUT"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$OUT/OnCue-$VERSION-$BUILD_NUMBER.dmg"
rm -f "$DMG"
hdiutil create -volname "OnCue $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null

if [ "$IDENTITY" != "-" ]; then
  codesign --force --sign "$IDENTITY" --timestamp "$DMG"
  if [ -n "${NOTARY_KEY_PATH:-}" ]; then
    xcrun notarytool submit "$DMG" --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER" --wait
  elif [ -n "${NOTARY_APPLE_ID:-}" ]; then
    xcrun notarytool submit "$DMG" --apple-id "$NOTARY_APPLE_ID" --password "$NOTARY_PASSWORD" --team-id "$TEAM" --wait
  else
    echo "Signed but not notarized (no notary credentials set): Gatekeeper will warn on other Macs."
  fi
  if [ -n "${NOTARY_KEY_PATH:-}${NOTARY_APPLE_ID:-}" ]; then
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG" || true
  fi
fi

hdiutil verify "$DMG" >/dev/null
echo "Made $DMG ($(du -h "$DMG" | cut -f1))"
