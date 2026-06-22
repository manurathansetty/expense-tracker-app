#!/usr/bin/env bash
# Build an unsigned, single-app Pi.ipa for sideloading via AltStore / SideStore.
# AltStore re-signs it with your free Apple ID on install, so this build is
# intentionally unsigned and drops the widget + share extensions (which can't
# share data on free signing anyway) to stay within the free 3-app limit.
#
# Usage:  ./scripts/make-ipa.sh
# Output: dist/Pi.ipa   (AirDrop this to your iPhone, then open it in AltStore)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ Generating single-target project from project.sideload.yml"
xcodegen generate --spec project.sideload.yml >/dev/null

echo "→ Building unsigned Release app for device"
xcodebuild -project PiSideload.xcodeproj -scheme Pi \
  -sdk iphoneos -configuration Release \
  -derivedDataPath ./build-ipa \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  clean build >/dev/null

APP="$(find ./build-ipa/Build/Products/Release-iphoneos -maxdepth 1 -name 'Pi.app' | head -1)"
[ -d "$APP" ] || { echo "✗ build failed: Pi.app not found"; exit 1; }

echo "→ Packaging dist/Pi.ipa"
STAGE="$(mktemp -d)"
mkdir -p "$STAGE/Payload" dist
cp -R "$APP" "$STAGE/Payload/"
( cd "$STAGE" && zip -qr -X "$OLDPWD/dist/Pi.ipa" Payload )
rm -rf "$STAGE"

echo "✓ dist/Pi.ipa ready ($(du -h dist/Pi.ipa | cut -f1))"
