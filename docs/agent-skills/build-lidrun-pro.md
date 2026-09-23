# Agent skill — build LidRun-like Pro app

Use when implementing or reviewing this app.

## Procedure

1. Read `AGENTS.md` and `specs/state.yaml`.
2. Read `specs/product/PRO_FEATURES_LATEST.yaml` for feature parity target.
3. Pick exactly one story from the active epic.
4. Trace existing code before editing.
5. Prefer native Swift/macOS APIs before dependencies.
6. Add one small runnable check for non-trivial logic.
7. Update `specs/state.yaml.next_step` before stopping.

## Safety checklist

- Does this change ever hold a power assertion?
- What releases it?
- Is the stop reason logged?
- Does a guardrail override convenience?
- Is the user warned about closed-lid heat/airflow?

## Done

- Feature works locally.
- Event log records it.
- UI explains current/stop reason.
- Spec state updated.
