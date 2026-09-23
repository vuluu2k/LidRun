# AGENTS.md

## Project
Build a native macOS menu-bar app like LidRun Pro: keep AI/dev work alive, including closed-lid workflows, with safety guardrails.

## Read first

```text
specs/state.yaml
specs/product/SCOPE_LATEST.yaml
specs/product/PRO_FEATURES_LATEST.yaml
specs/tech-architecture/TECH_STACK_LATEST.md
specs/agents/CONTEXT_STABILITY.md
```

## Build rules

- Native Swift/macOS APIs first.
- No backend until local Pro features work.
- Safety releases beat user convenience.
- Log every start/stop/guardrail event locally.
- Keep UI explanations plain: Why Awake, Why Stopped, Next Release.
- One small runnable check for non-trivial logic.

## Feature order

1. Manual keep-awake + timer.
2. Battery/power/thermal guardrails.
3. Auto Mode process detection.
4. CLI `apprun -- <command>`.
5. Watchdog rules.
6. Alerts + webhooks.
7. Dashboard + weekly local reports.
8. Signing/notarized DMG.

## Definitions

- Assertion: macOS power assertion that prevents sleep.
- Session: one period where the app intentionally holds awake.
- Guardrail: safety condition that can release the assertion.
- Rule: user condition that can start/keep/stop/alert.
