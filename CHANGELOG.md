# Changelog

All notable changes to LidRun Personal. Releases are built automatically from
`main` and numbered `0.1.<build>`; builds that failed are folded into the next
release.

## 0.1.23 — 2026-09-23

### Fixed
- The Update button now actually restarts into the new version. The installer never stopped the running app (macOS `pgrep` skips the calling process's ancestors, and the app is one), so the new version was installed but the old one kept running.
- New releases show up right away instead of up to 10 minutes later (the release check no longer uses the HTTP cache).

## 0.1.22 — 2026-09-23

### Added
- **Watch a process**: pick something already running (a build, training job, download); LidRun keeps the Mac awake until it exits, notifies you, and can put the Mac to sleep.
- **Phone push via ntfy.sh**: free push notifications when a job finishes or a safety stop happens (Settings → Notifications; generate a private topic and subscribe in the ntfy app).
- **URL scheme** for Shortcuts, Raycast, Alfred and scripts: `lidrun://start?minutes=60`, `lidrun://stop`, `lidrun://toggle`, `lidrun://auto?on=1`, `lidrun://closedlid?on=0`, `lidrun://watch?pid=123`.
- **Menu bar countdown**: timed sessions show the time left next to the icon.
- **Daily schedule**: keep the Mac awake during a daily window (e.g. 01:00–07:00, overnight windows supported); stopping it manually pauses it until the window ends.
- **What's new**: the update button lists the changes in the new version before installing.

### Changed
- Notifications and the activity report are fully localized (start/stop reasons in Vietnamese); report dates are shorter.

## 0.1.21 — 2026-09-23

### Fixed
- In-app updates now relaunch the new version: the installer stops every running copy of the app (any location) and removes duplicate installs in /Applications and ~/Applications.
- Metric chip icons sit level with their text; the battery icon follows the real charge level, and each chip has a tooltip.

## 0.1.20 — 2026-09-23

### Fixed
- Website: balanced donate layout, with link cards stacked beside the QR card.

## 0.1.19 — 2026-09-23

### Added
- Website: VietQR bank transfer (Vietcombank) option in the donate section.

## 0.1.18 — 2026-09-23

### Added
- `apprun` is bundled with the app; Settings can install it to `/usr/local/bin/apprun`, and it keeps working across updates.
- Crash guard: if the app dies while Closed-Lid sleep blocking is on, sleep is restored automatically.
- Timer shows the end time and remaining time (e.g. "until 15:30 · 1h 12m"); open-ended sessions show the watchdog cap.
- Report lists recent runs with duration and stop reason.
- Website: favicon, share preview image and a donate section (GitHub Sponsors, Buy Me a Coffee).

### Fixed
- Quitting waits up to 3 seconds so the "stopped" webhook is delivered.
- Timers keep counting correctly across sleep.
- Launch at Login keeps working after the app is renamed or moved.
- Remaining untranslated English strings are now localized.

## 0.1.17 — 2026-09-23

### Fixed
- Panel sizes to its content so top and bottom padding are no longer clipped; the fallback window has a dark title bar.

## 0.1.16 — 2026-09-23

### Changed
- The ambiguous laptop On/Off chip is replaced by how long the Mac has been kept awake.

## 0.1.15 — 2026-09-23

### Changed
- Renamed to "LidRun Personal.app" so it no longer collides with the unrelated commercial LidRun; the installer migrates the old app and never touches someone else's.
- Much lower idle CPU (about 1–2% down to about 0.1%): heavy monitoring only runs while the panel is open or Auto Mode needs it.
- Website: live HTML panel preview, updated feature cards and FAQ, not-affiliated note.

### Added
- Safety checklist before enabling Closed-Lid Mode, and a heat warning while it is on.

## 0.1.14 — 2026-09-23

### Added
- Optional Full Closed-Lid mode: a one-time admin prompt allows LidRun to block sleep with the lid shut; normal sleep is restored on every stop, guardrail, quit and launch.
- Low-battery guardrail puts the Mac to sleep; guardrail stops with the lid shut also sleep.
- `apprun --sleep`; `apprun` uses the app's guardrail settings and sends a `command_finished` event.
- Opt-in extended Auto Mode detection: Python, Node, SSH/rsync, Xcode builds and network transfers over 1 MB/s.
- Closed-Lid arm/disarm events are logged.

## 0.1.13 — 2026-09-23

### Fixed
- Website: Vietnamese text renders in a single font (Be Vietnam Pro).

## 0.1.12 — 2026-09-23

### Fixed
- Removed the hotspot temperature stop and alert that fired under normal load on Apple Silicon; macOS thermal state remains the guardrail.
- LidRun refuses to start while a guardrail blocks, ending Auto Mode start/stop loops; a manual stop pauses Auto Mode, and turning Auto Mode off stops its session.
- Keep Awake no longer clears "Only When Charging".
- Low-battery threshold, watchdog Off and webhook token are now saved.
- Switching sessions no longer triggers a phantom stop.
- The watchdog has its own stop reason and only caps open-ended sessions.
- Closed-Lid Mode requires AC power (macOS ignores it on battery).
- Auto Mode matches exact process names and ignores idle helpers (e.g. idle Docker/Ollama, the Claude desktop app).
- `apprun` returns standard exit codes (127 for missing commands, 128+N on signals) and forwards Ctrl-C and termination signals to the command.
- Weekly report reads more history; scripts never touch an unrelated /Applications/LidRun.app.

## 0.1.11 — 2026-09-23

### Fixed
- The DMG mounts without being blocked by Gatekeeper.

## 0.1.10 — 2026-09-23

### Added
- Website: copy button for the install command.

## 0.1.9 — 2026-09-23

### Fixed
- Copy and paste shortcuts work in text fields.

## 0.1.8 — 2026-09-23

### Added
- In-app update button: LidRun checks for a new version at launch and daily, and updates and relaunches itself.

## 0.1.7 — 2026-09-23

### Fixed
- Crash at launch in release builds (notification permission handling).

### Added
- Install script that installs without security prompts.

## 0.1.5 — 2026-09-23

### Added
- App icon.

### Fixed
- The panel opens when the menu bar icon is hidden.

## 0.1.4 — 2026-09-23

### Changed
- Released under the MIT license.

## 0.1.3 — 2026-09-23

### Fixed
- The downloaded file keeps the LidRun name.

## 0.1.2 — 2026-09-23

### Added
- First release: LidRun menu bar keep-awake app and download website.
