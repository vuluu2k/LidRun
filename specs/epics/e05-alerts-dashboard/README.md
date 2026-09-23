# E05 — Alerts, webhooks, dashboard, reports

## Goal
Make the app explain itself and notify the user when unattended work changes state.

## Stories

### E05S01 — macOS alerts
- Notify on start, stop, guardrail release, command finish, watchdog alert.
- Include clear reason and session duration.

### E05S02 — Webhooks
- POST event JSON to a configured URL.
- Store token locally.
- Retry lightly; never block safety release.

### E05S03 — Dashboard
- Show active session.
- Show recent runs and stop reasons.
- Show protected hours and rescue count.

### E05S04 — Weekly local report
- Summarize protected hours, common workloads, and guardrail rescues.
- Export markdown.

## Acceptance
- [x] User can answer “what happened while I was away?” from local app data.

## Implementation notes
- macOS start/stop notifications can be enabled locally.
- Webhook URLs receive JSON start/stop events.
- Tasks & Reports shows seven-day protected time, sessions, safety stops, recent events, and copies a Markdown weekly report.
