# E02 — Safety guardrails

## Goal
Safety conditions automatically release the Mac before convenience becomes risk.

## Stories

### E02S01 — Charging-only release
- User can require AC power.
- App releases when power adapter disconnects.
- Stop reason is recorded.

### E02S02 — Low-battery release threshold
- User can set a low-battery threshold.
- App releases at or below threshold.
- Default threshold is conservative.

### E02S03 — Thermal-pressure release
- App watches macOS thermal state.
- App releases on unsafe thermal pressure.
- UI explains that ventilation is still the user’s responsibility.

## Acceptance
- [x] Each guardrail can independently stop a session.
- [x] Safety wins over timer/manual preference.

## Implementation notes
- `Sources/LidRunCore/Guardrails.swift` contains the pure `SafetyGovernor` plus macOS power/thermal reader.
- `Sources/LidRunPersonal/main.swift` polls guardrails during active sessions.
- `Tests/LidRunCoreTests/GuardrailsTests.swift` covers charging-only, low-battery, thermal, and safe states.
