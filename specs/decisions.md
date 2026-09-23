# Decisions

## 2026-09-22 — Native macOS first
Use Swift/SwiftUI + IOKit. Skip Electron/backend for the first product because sleep assertions, battery, thermal state, menu-bar UI, notifications, signing, and CLI integration are all native macOS concerns.

## 2026-09-22 — Local Pro before cloud
Implement Pro-like features locally first: Closed-Lid Mode, Auto Mode, Run Command, Watchdog, Alerts, Webhooks, Dashboard, Weekly Reports. Defer licensing, teams, and cloud analytics.

## 2026-09-22 — Context stability is a product asset
Keep `AGENTS.md`, `specs/state.yaml`, product specs, and active epic docs current so agents can resume without chat history.
