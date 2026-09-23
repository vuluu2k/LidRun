#!/bin/bash
# Installs the latest LidRun: curl -fsSL https://vuluu2k.github.io/LidRun/install.sh | bash
# curl downloads carry no quarantine flag, so Gatekeeper does not block the first launch.
set -euo pipefail

SITE="${LIDRUN_SITE:-https://vuluu2k.github.io/LidRun}"
APP="${LIDRUN_APP:-/Applications/LidRun Personal.app}"
BUNDLE_ID="io.opensource.lidrun"
# Builds before 0.1.15 were called LidRun.app, which clashes with the unrelated commercial LidRun; migrate them.
OLD="/Applications/LidRun.app"
if [[ "$(basename "$APP")" == "LidRun.app" ]]; then OLD="$APP"; APP="$(dirname "$APP")/LidRun Personal.app"; fi
ours() { [[ "$(defaults read "$1/Contents/Info.plist" CFBundleIdentifier 2>/dev/null)" == "$BUNDLE_ID" ]]; }
TMP="$(mktemp -d)"
trap 'hdiutil detach -quiet "$TMP/mnt" 2>/dev/null || true; rm -rf "$TMP"' EXIT

curl -fsSL "$SITE/download.json" -o "$TMP/release.json"
field() { plutil -extract "$1" raw -o - "$TMP/release.json"; }
echo "Downloading LidRun $(field version)..."
curl -fL --progress-bar "$(field url)" -o "$TMP/LidRun.dmg"
[[ "$(shasum -a 256 "$TMP/LidRun.dmg" | cut -d ' ' -f 1)" == "$(field sha256)" ]] || { echo "Checksum mismatch, aborting." >&2; exit 1; }

if [[ -d "$APP" ]] && ! ours "$APP"; then
  echo "$APP belongs to a different app; not overwriting it. Move or rename it, then rerun." >&2
  exit 1
fi

hdiutil attach -quiet -nobrowse -mountpoint "$TMP/mnt" "$TMP/LidRun.dmg"
pkill -f "$APP/Contents/MacOS/LidRun" 2>/dev/null || true
if [[ -d "$OLD" ]] && ours "$OLD"; then pkill -f "$OLD/Contents/MacOS/LidRun" 2>/dev/null || true; rm -rf "$OLD"; fi
rm -rf "$APP"
ditto "$(ls -d "$TMP"/mnt/*.app | head -1)" "$APP"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
open "$APP"
echo "Installed $APP — look for the moon icon in the menu bar."
