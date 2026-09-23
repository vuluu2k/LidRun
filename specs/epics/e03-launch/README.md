# E03 — Usable first release

## Goal
Package the MVP into something a developer can safely try.

## Stories

### E03S01 — Activity log persisted locally
- Record start, stop, and guardrail events.
- Show the last events in the app.
- Keep logs local.

### E03S02 — Common dev workload detection
- Detect common processes: Claude Code, Cursor, Docker, Ollama, terminal shells.
- Use detection only as explanation first; manual mode remains enough for MVP.
- Avoid complex per-app automation until users ask for it.

### E03S03 — Safety onboarding and release checklist
- Show clear closed-lid safety warning.
- Document limits: ventilation, battery, thermal state.
- Create a local release checklist.

## Acceptance
- A new user understands what the app does and what it cannot guarantee.
- MVP can be demoed without a backend.
