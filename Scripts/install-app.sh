#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD_APP="$PWD/.build/LidRun.app"
APP_OUTPUT="$BUILD_APP" SIGN_IDENTITY=- ./Scripts/build-app.sh
pkill -x LidRunPersonal 2>/dev/null || true
pkill -x LidRun 2>/dev/null || true
rm -rf "/Applications/LidRun.app"
ditto "$BUILD_APP" "/Applications/LidRun.app"
open "/Applications/LidRun.app"
echo "Installed: /Applications/LidRun.app"
