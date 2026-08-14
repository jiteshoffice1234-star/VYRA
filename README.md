# VYRA

A modern, offline-first personal productivity app that combines a **Daily Journal**, a **Habit Tracker** and **Notes** in one beautiful, minimal package.

> **Version 1 (MVP).** Everything runs 100% locally — no login, no cloud, no APIs. The architecture is deliberately structured so AI features (journal summaries, habit insights, voice journal, OCR, cloud sync…) can be plugged in later without rewriting the app.

---

## Features

- **Home dashboard** — greeting, today's habit progress, quick-add buttons, recent journal & notes, quote of the day, calendar preview, statistics cards and weekly progress chart.
- **This Week review** — weekly completion, best day, mood trend and streak changes with a generated recap (from the Insights tab).
- **Journal** — create / edit / delete / view, mood selection, tags, title + content, word & character counts, search, favorite, filter by date, calendar view.
- **Habit tracker** — good & bad habits, daily streaks, longest streak, weekly & monthly views, calendar history, completion percentage, color labels, categories, daily reminders (tap the notification to open the habit).
- **Notes** — create / edit / delete, pin, favorite, search, tags, checklist notes, categories, color notes.
- **Settings** — light / dark / system theme, 6 accent colors, 3 theme styles, JSON export, backup & restore (create, list, validate, import, delete), privacy statement, about + version.
- **Backup & restore** — full local backup to a JSON file: automatic duplicate detection, validation of restored files, restore with confirmation, and import from an existing backup file.

---

## Tech Stack

| Concern         | Choice                                   |
| --------------- | ---------------------------------------- |
| UI              | Flutter (Material 3, custom theme)       |
| State           | Riverpod (`flutter_riverpod`)            |
| Navigation      | go_router (stateful shell + custom pages)|
| Database        | SQLite via `sqflite` (+ `sqflite_common_ffi` on desktop) |
| Settings        | `shared_preferences`                     |
| Locale/format   | `intl`                                   |
| Reminders       | `flutter_local_notifications` + `timezone` |

The database runs on Android / iOS and also on Windows / macOS / Linux desktop for local testing.

---

## Getting Started

```bash
# 1. Install Flutter (latest stable) — https://docs.flutter.dev/get-started/install
# 2. Generate the platform folders (android/, ios/, etc.) if missing:
flutter create .

# 3. Fetch dependencies
flutter pub get

# 4. Run on a device / emulator / desktop
flutter run

# 5. Run the tests
flutter test
```

> If you generated the project without `flutter create .`, the app still works; platform folders are only needed to launch on a device.

---

## Architecture

Clean Architecture with a strict one-way data flow, kept scalable for future modules (AI chat, sync, analytics…).

```
lib/
├── main.dart                      # Entry point (ProviderScope)
├── app.dart                       # MaterialApp.router + theme wiring
│
├── core/                          # Framework-agnostic foundations
│   ├── constants/app_constants.dart
│   ├── theme/app_theme.dart       # Material 3 light/dark from seed
│   ├── theme/mood_colors.dart
│   ├── utils/date_utils.dart
│   ├── utils/text_utils.dart
│   ├── database/app_database.dart # SQLite schema + migrations
│   ├── router/app_router.dart     # go_router config
│   └── widgets/                   # Reusable UI primitives
│
├── domain/                        # Pure Dart: models + business rules
│   ├── models/                    # Mood, Category, Tag, JournalEntry,
│   │                              # Habit, HabitLog, Note, ChecklistItem
│   └── services/habit_stats.dart  # Streak / completion math (unit tested)
│
├── data/                          # Persistence
│   └── repositories/              # SQL access + mapping
│
├── application/                   # Riverpod providers (state + logic)
│   ├── providers/
│   └── settings/
│
└── presentation/                  # Flutter UI
    ├── navigation/main_shell.dart # Bottom nav + contextual FAB
    ├── screens/                   # home, journal, habits, notes, settings
    └── widgets/                   # Screen-shared components
```

Layers depend inward: **presentation → application → data/domain → core**. Models are plain Dart objects with `fromMap` / `toMap` — swap SQLite for Hive or a remote API later by replacing only the `data/` layer.

---

## Database Schema (SQLite)

```
categories(id, name, color, kind['habit'|'note'])
tags(id, name UNIQUE)
journal_entries(id, title, content, mood, is_favorite, entry_date, created_at, updated_at)
journal_tags(journal_id, tag_id)          -- PK(journal_id, tag_id)
habits(id, name, description, type['good'|'bad'], color, icon_index,
        category_id, target_per_day, reminder_time, reminder_enabled, created_at)
habit_logs(id, habit_id, date, count, note, created_at)  -- UNIQUE(habit_id, date)
notes(id, title, content, type['text'|'checklist'], color, is_pinned,
       is_favorite, category_id, created_at, updated_at)
note_tags(note_id, tag_id)                -- PK(note_id, tag_id)
checklist_items(id, note_id, text, is_checked, position)
```

Dates are stored as `yyyy-MM-dd` for simple day-based queries (streaks, calendars).

---

## Roadmap

### Shipped in v1

- **Backup & restore** — full JSON export / import with validation, duplicate detection and delete; restore replaces the local database after confirmation.
- **Habit reminders** — daily local notifications scheduled from the habit editor; rescheduled on edit, cancelled on delete/archive, re-scheduled after a backup restore, and tapping a notification opens the habit's detail screen.
- **This Week review** — a rule-based weekly recap of completion, best day, moods and streaks (see Features).
- **Analytics** — habit completion, mood trends, journal frequency, best day / month, categories and recent activity.
- **Search** — highlighted results across journals, habits and notes with recent-search history.

### Planned

The structure anticipates these without implementing them:

- **AI companion** — journal summaries, habit insights and richer weekly reviews. An `ai_service` interface with an offline fallback already exists; a small on-device model would keep the app 100% offline, or an optional cloud API can plug into the same interface.
- **Voice journal / OCR / image analysis** — new input paths into the journal editor.
- **Cloud sync & authentication** — only the `data/repositories` layer needs to change.
- **NVIDIA NIM API integration** — a dedicated `data/remote/` datasource behind the same repositories.
- **Home-screen widgets & wearables** — the dashboard provider is the single source of stats.

---

## License

Private project. All data stays on your device.
