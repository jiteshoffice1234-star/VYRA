# Changelog

All notable changes to VYRA are documented here. The app is fully offline-first: journal, habits, notes, streaks, and an on-device AI companion — your data never leaves the device.

## [2.0.0] - 2026-08-14

### Added
- **Habit reminders** — schedule a daily reminder per habit from the saved reminder time. Reminders reschedule on edit/delete and re-register after a backup restore. Tapping the notification opens the habit's detail screen. Android notifications via `flutter_local_notifications` (permission requested on first use).
- **This Week review screen** — weekly completion rate, best day, mood trend, streak changes, and a generated plain-text summary, built from `AnalyticsService` data. Accessible from the home dashboard.
- **Past-day completion logging** — the history calendar in the habit detail screen is now tappable; tap any past day to add or adjust its count, reusing the existing `setCount`/`countsGrouped` logic.
- **Reminder section on habit detail** — shows the scheduled time with a quick enable/disable toggle.
- **APK published in-repo** — `apk/VYRA-v2.0.0.apk` committed for direct download from GitHub.

### Changed
- README rewritten: backup/restore and export documented as **implemented** (not placeholders); AI and voice features moved to an explicit roadmap section.
- Backup listing switched to async `dir.list()` — no more UI-thread blocking when listing backups.
- Web preview fully redesigned (the "Chain Ledger" theme: paper + ink + chain-red), with variable-font delivery (one font file per family) and reduced-motion/focus-visible support.

### Fixed
- Backup restore no longer silently drops habit reminders — they are rescheduled after import.
- Notification tap routing validates the payload before navigation.
- Week-review test fixture corrected (logged yesterday, asserted today).

### Quality
- 96 tests passing; `flutter analyze` clean (0 errors, 0 warnings).
- Static verification tooling added under `tools/` for SDK-less environments.

## [1.0.0] - 2026-08-04

### Added
- Initial release: offline-first journal, habits, notes, and AI companion app.
- Android platform support with a custom launcher icon; builds and tests passing.

## [0.x] - Early development

- Concept and local prototypes; not published.
