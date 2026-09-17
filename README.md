# RoutineTime

Simple recurring reminders for the small things you do every day.

RoutineTime is a private, offline-first routine reminder app built with Flutter.
Its core loop is intentionally small:

Create -> Remind -> Done.

## Features

- Today screen with routines ordered by time
- One-screen routine creation
- Actionable notifications with Done and Snooze
- Smart repeat schedules: every day, weekdays, weekends, specific days, every X days, and once
- Simple history for completed routines
- Local SQLite storage
- Optional encrypted backup and restore
- Light, dark, and system themes

## Positioning

RoutineTime is not a habit tracker. It does not center streaks, challenges,
journaling, or heavy analytics. The product promise is simpler:

Never forget the small things you do every day.

## Technical Stack

- Flutter
- Dart
- Provider
- SQLite via sqflite
- flutter_local_notifications
- shared_preferences

## Getting Started

```bash
flutter pub get
flutter run
```

## Data

RoutineTime stores all routine data locally on your device. There are no
accounts, cloud sync, ads, analytics, or purchase integrations. The only
third-party service is Firebase Crashlytics, used for anonymous crash reports.
