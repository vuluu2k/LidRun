# Tech stack — LidRun-like macOS app

## Decision
Build native first.

- App: Swift + SwiftUI menu-bar app.
- Sleep assertions: IOKit power assertions (`IOPMAssertionCreateWithName`, release by id).
- Battery/power: IOKit power sources.
- Thermal: `ProcessInfo.processInfo.thermalState` plus notifications.
- Process detection: `NSWorkspace.runningApplications` first; `ps` fallback only if needed.
- CLI: small Swift executable installed from Settings.
- Persistence: local JSONL event log + UserDefaults for settings.
- Dashboard: SwiftUI window reading local log.
- Webhooks: `URLSession`.
- Packaging: signed `.app`; DMG/notarization later.

## Architecture

```text
MenuBar UI
  -> SessionController
      -> PowerAssertion
      -> GuardrailMonitor
      -> WorkloadDetector
      -> RuleEngine
      -> EventLog
      -> Notifier
      -> WebhookClient
CLI
  -> CommandRunner
  -> SessionController
Dashboard
  -> EventLog reader
```

## Boring constraints

- Safety always wins over convenience.
- Local-only by default.
- One event log is enough until it hurts.
- No backend before local Pro features work.
- No dependency unless Swift/macOS cannot do it.

## Risk notes

- Closed-lid behavior is hardware/macOS constrained. The app should say “reduce risk”, not “guarantee”.
- Fan control is not a promise, especially on Apple Silicon.
- App Store distribution may be painful due to power-management behavior; start with direct download.
