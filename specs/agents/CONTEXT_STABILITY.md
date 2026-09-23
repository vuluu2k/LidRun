# Agent context stability plan

Goal: make future AI coding sessions restartable without re-explaining the app.

## Files agents must read first

1. `AGENTS.md` — working rules and current command set.
2. `specs/state.yaml` — current project state and next step.
3. `specs/product/SCOPE_LATEST.yaml` — product boundary.
4. `specs/product/PRO_FEATURES_LATEST.yaml` — paid-feature parity target.
5. `specs/tech-architecture/TECH_STACK_LATEST.md` — architecture decisions.
6. Active epic README under `specs/epics/`.

## Context protocol

- Before coding: update `specs/state.yaml.current_focus`.
- After a decision: append/update `specs/decisions.md`.
- After implementation: update the active epic README acceptance status.
- Before stopping: write the exact next command/task into `specs/state.yaml.next_step`.

## Anti-rot rules

- Do not scatter requirements in chat only.
- Do not add hidden behavior without a spec entry.
- Do not invent backend work unless a spec says so.
- Prefer one small runnable check per non-trivial module.
