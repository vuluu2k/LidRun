#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD_APP="$PWD/.build/LidRun.app"
APP_OUTPUT="$BUILD_APP" SIGN_IDENTITY=- ./Scripts/build-app.sh
pkill -x LidRunPersonal 2>/dev/null || true
TARGET="/Applications/LidRun.app"
if [[ -d "$TARGET" && "$(defaults read "$TARGET/Contents/Info.plist" CFBundleIdentifier 2>/dev/null)" != "io.opensource.lidrun" ]]; then
  echo "$TARGET belongs to a different app; not overwriting it." >&2
  exit 1
fi
pkill -f "$TARGET/Contents/MacOS/LidRun" 2>/dev/null || true
rm -rf "$TARGET"
ditto "$BUILD_APP" "/Applications/LidRun.app"
open "/Applications/LidRun.app"
echo "Installed: /Applications/LidRun.app"
