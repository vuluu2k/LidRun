# E01 — Local keep-awake session MVP

## Goal
User can start/stop a guarded awake session and see why the Mac is awake.

## Stories

### E01S01 — Start and stop manual keep-awake session
- Start a keep-awake assertion from the app.
- Stop it manually.
- App never leaves a stale assertion after quit/crash recovery.

### E01S02 — Timer-limited sessions
- User chooses a duration from 30 minutes to 8 hours.
- Timer expiry releases the assertion.
- Stop reason is recorded.

### E01S03 — Current status and awake reason
- UI shows active/inactive state.
- UI shows awake reason: manual, timer, or guardrail.
- UI shows next automatic release condition.

## Acceptance
- [x] Manual session works locally without backend.
- [x] Timer release works.
- [x] Status is visible in the menu-bar UI or simplest equivalent.

## Implementation notes
- `Sources/LidRunCore/PowerAssertion.swift` holds/releases `kIOPMAssertionTypeNoIdleSleep`.
- `Sources/LidRunCore/SessionController.swift` owns manual/timed sessions.
- `Sources/LidRunPersonal/main.swift` provides the menu-bar UI.
- `Tests/LidRunCoreTests/SessionControllerTests.swift` covers start/stop event logging.
