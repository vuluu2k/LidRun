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

The app bundle ships `apprun`; Settings → Command line tool → Install links it to `/usr/local/bin/apprun` (one admin prompt). From source you can also use `swift run apprun`.

`apprun` holds the awake assertion until the command exits and returns the same exit code. It uses the app's charging-only, low-battery and thermal settings, and posts a `command_finished` webhook when one is configured. Add `--sleep` to put the Mac to sleep when the command finishes:

```bash
apprun --sleep -- ./train.sh
```

### Overnight agent queue

Queue jobs, then run them one after another. The Mac stays awake until the queue is empty, each result is pushed to your phone (ntfy) and webhook, and a guardrail stop (low battery, heat) pauses the queue with the remaining jobs kept:

```bash
apprun queue add -- claude -p "implement docs/plan.md step 1, run tests"
apprun queue add -- claude -p "implement docs/plan.md step 2, run tests"
apprun queue              # list
apprun --sleep queue run  # sleep when done
```

The queue is a plain file (`~/Library/Application Support/LidRunPersonal/queue.txt`, one shell command per line) you can edit by hand. Ctrl-C stops the queue; `apprun queue pause` / `resume` (or the Job queue sheet in the menu bar panel) lets the current job finish and holds the rest. Each job's output is saved under `LidRunPersonal/logs/`, and the last lines are included in the push. Queued jobs write to a pipe, not a terminal, so queue non-interactive commands (`claude -p`, `codex exec`, test scripts), not TUIs.

### Push when an agent is stuck

An agent waiting for a permission or an answer sits idle all night. Add this to `~/.claude/settings.json` to get a phone push instead:

```json
{
  "hooks": {
    "Notification": [{ "hooks": [{ "type": "command", "command": "apprun notify 'Claude needs you'" }] }]
  }
}
```

`apprun notify [title]` reads the hook JSON on stdin and sends `project: message`.

Without any hook, LidRun also pushes "Agent looks stuck" when Claude Code or Codex keeps the Mac awake but has used almost no CPU for 15 minutes.

### Drive Claude from your phone (Remote Control)

Claude Code's own [Remote Control](https://code.claude.com/docs/en/remote-control) lets you approve permissions and send new prompts from the Claude mobile app, but only while the Mac stays awake and online. Run `claude remote-control` with Auto Mode on (it is detected as Claude Code), or add Closed-Lid Mode to keep it reachable with the lid shut. The idle `remote-control` server is not reported as a stuck agent.

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
- Auto Mode detects Claude Code, Codex, Cursor, Docker, and Ollama via local process list.
- Auto Mode starts when a known workload appears and releases when it ends.
- Low battery puts the Mac to sleep instead of only releasing the assertion.
- Battery forecast: the panel shows when the low-battery stop will come (from macOS's time-to-empty estimate), and LidRun warns when a timer outlasts the battery or the stop is under 30 minutes away.
- Optional extended Auto Mode: Python, Node, SSH/rsync, Xcode builds and transfers above ~1 MB/s.
- Full Closed-Lid Mode (optional): Settings → Install asks for the admin password once and adds `/etc/sudoers.d/lidrun`, which allows only `pmset -a disablesleep 0|1`. The lid can then close on battery too. Sleep is re-enabled on every stop, guardrail release and app launch; Settings → Remove deletes the rule.
- Watch an already-running process until it exits (optionally sleep afterwards).
- Phone push notifications through ntfy.sh (free, no account). Notifications → choose which pushes you get (stuck agent, battery, job results) and an "only notify between" window; heat warnings always go through, webhooks get every event.
- URL scheme: `open "lidrun://start?minutes=60"`, `lidrun://stop`, `lidrun://toggle`, `lidrun://auto?on=1`, `lidrun://closedlid?on=0`, `lidrun://watch?pid=123`.
- Daily keep-awake schedule and a menu bar countdown for timed sessions.
- In-app updates show release notes (generated by CI from `feat`/`fix` commits). See [CHANGELOG.md](CHANGELOG.md).
- Local JSONL event log at `~/Library/Application Support/LidRunPersonal/events.jsonl`.
