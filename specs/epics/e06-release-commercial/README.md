# E06 — Commercial release readiness

## Goal
Ship a trustworthy direct-download macOS app.

## Stories

### E06S01 — Signing and notarization
- Sign app and CLI.
- Notarize release artifact.
- Verify first-open flow.

### E06S02 — DMG packaging
- Build a drag-to-Applications DMG.
- Include version metadata.

### E06S03 — Safety docs
- Install guide.
- Closed-lid safety guide.
- FAQ with honest limitations.

### E06S04 — Optional licensing later
- Keep hooks for licensing out of core safety path.
- Do not require network to release sleep.

## Acceptance
- A user can download, open, and run the app without Xcode.
