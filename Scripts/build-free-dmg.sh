#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${VERSION:-0.1.0}"
DIST="$PWD/dist"
STAGE="$DIST/dmg-root"
APP="$STAGE/LidRun.app"
DMG="$DIST/LidRun-$VERSION-unsigned.dmg"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
CONFIGURATION=release VERSION="$VERSION" APP_OUTPUT="$APP" SIGN_IDENTITY=- ./Scripts/build-app.sh
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/INSTALL.txt" <<'TXT'
LidRun — free open-source build

1. Drag LidRun.app to Applications.
2. Open LidRun once; macOS blocks it. Click Done.
3. System Settings → Privacy & Security → Open Anyway. macOS remembers this choice.

No-prompt alternative: curl -fsSL https://vuluu2k.github.io/LidRun/install.sh | bash

This build is ad-hoc signed and not Apple-notarized, so a normal double-click may show an
"unidentified developer" warning. The source code is available for inspection and local builds.
TXT

hdiutil create -volname "LidRun" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --force --sign - "$DMG"
shasum -a 256 "$DMG" > "$DMG.sha256"
rm -rf "$STAGE"

echo "Created: $DMG"
echo "Checksum: $DMG.sha256"
echo "Free distribution note: users must right-click → Open on first launch."
