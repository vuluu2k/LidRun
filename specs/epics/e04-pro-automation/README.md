# E04 — Pro automation

## Goal
Match the core Pro value: closed-lid workflows, Auto Mode, Run Command, and watchdog rules.

## Stories

### E04S01 — Closed-Lid Mode
- [x] User explicitly arms closed-lid mode.
- [x] App shows the public-API safety limitation.
- [x] Guardrails release both idle-sleep and system-sleep assertions.

### E04S02 — Auto Mode workload detection
- [x] Detect Claude Code, Cursor, Docker, Ollama.
- [x] Hold awake while selected workloads are active.
- [x] Show Why Awake.

### E04S03 — Run Command CLI
- [x] `apprun -- <command>` starts a watched session.
- [x] Session releases when command exits.
- [x] Exit code, duration, and safety stop are recorded locally.

### E04S04 — Watchdog rules
- [x] Process, time, power, and thermal rules are available.
- [x] Rule result is visible in current status.
- [x] Stop/alert events are logged.

## Acceptance
- [x] A developer can start a command, arm closed-lid mode, and have assertions release when the command ends or a guardrail triggers.

## Implementation notes
- `Sources/LidRunCore/WorkloadDetector.swift` matches known local dev workloads from `ps` output.
- `Sources/LidRunPersonal/main.swift` has an Auto Mode toggle; it starts an Auto Mode session when workloads appear and stops when they end.
- `Tests/LidRunCoreTests/WorkloadDetectorTests.swift` covers known workload matching.
- `Sources/LidRunCore/CommandRunner.swift` holds awake around a child command and preserves its exit code.
- `Sources/AppRun/main.swift` provides `swift run apprun -- <command>`.
- The menu app now uses a custom SwiftUI popover instead of a plain `NSMenu`.
