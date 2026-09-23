# LidRun Personal

Native macOS keep-awake app inspired by LidRun. Free and open source under the [MIT License](LICENSE).

## Run dev app

```bash
./Scripts/run-app.sh
```

This builds a real `.app` bundle and opens it through macOS LaunchServices. Look for the moon icon in the menu bar and click it to open the SwiftUI control panel.

Do not use `swift run lidrun-personal` for UI testing; the raw SwiftPM executable is not a reliable menu-bar app bundle.

## Run a protected command

```bash
swift run apprun -- /bin/sleep 30
swift run apprun -- docker build .
```

`apprun` holds the awake assertion until the command exits and returns the same exit code.

## Build a free DMG

```bash
./Scripts/build-free-dmg.sh
```

Artifacts:

- `dist/LidRun-0.1.0-unsigned.dmg`
- `dist/LidRun-0.1.0-unsigned.dmg.sha256`

This route costs nothing. Because it has no paid Apple Developer ID/notarization, users must right-click the app and choose **Open** on first launch.

## Website and automatic releases

The static bilingual site lives in `website/`. Preview it with:

```bash
python3 -m http.server 8000 --directory website
```

After this repository is pushed to GitHub on the `main` branch, `.github/workflows/build-and-pages.yml` tests the app, builds a DMG, uploads it to WebCake, updates the website download URL, and deploys GitHub Pages. Enable **Settings → Pages → Source: GitHub Actions** once in the repository.

Vercel can also serve the same site using the root `vercel.json`.

## Test

```bash
swift test
```

## Current features

- Manual keep-awake session.
- 30-minute and 2-hour timer sessions.
- Stop action releases the power assertion.
- Charging-only guardrail.
- Low-battery guardrail: 5%, 10%, or off.
- Thermal guardrail: releases on serious/critical macOS thermal pressure.
- Auto Mode detects Claude Code, Cursor, Docker, and Ollama via local process list.
- Auto Mode starts when a known workload appears and releases when it ends.
- Local JSONL event log at `~/Library/Application Support/LidRunPersonal/events.jsonl`.
