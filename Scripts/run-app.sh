#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
APP="$PWD/.build/LidRun Personal.app"
APP_OUTPUT="$APP" SIGN_IDENTITY=- ./Scripts/build-app.sh
pkill -x LidRunPersonal 2>/dev/null || true
pkill -f "$APP/Contents/MacOS/LidRun" 2>/dev/null || true
open "$APP"
echo "Opened: $APP"
