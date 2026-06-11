# Chiron

A personal app for guided exercise programs. Named after Chiron, the healer of Greek mythology.

## What it does

- Presents exercise programs as structured workouts
- Guides you through exercises with timed countdowns, rep cues, and audio beeps
- Tracks progressive overload — automatically increments weight or reps on schedule
- Persists settings and progression state between sessions via `shared_preferences`
- Keeps the screen on during workouts (`wakelock_plus`)

## Requirements

- Flutter SDK (see `environment.sdk` in `pubspec.yaml` for version constraint)
- Android device/emulator, or Chrome for web

## Running

```bash
flutter pub get

flutter run                        # dev flavor (example programs) on Android
flutter run -d chrome              # dev flavor on web
flutter run --flavor staging       # staging flavor on Android
flutter run --flavor production    # production flavor (requires programs_local.dart)
```

## Flavors

Three flavors are configured: `dev`, `staging`, and `production`. `dev` is the default, so plain `flutter run` / `flutter test` / CI always uses the example programs without any setup.

| Flavor | Program set | App ID suffix |
|---|---|---|
| `dev` | `programs_example.dart` (checked in) | `.dev` |
| `staging` | `programs_example.dart` (checked in) | `.staging` |
| `production` | `programs_production.dart` → `programs_local.dart` | — |

Program selection happens automatically via `appFlavor` in `programs_data.dart` — no manual file edits needed when switching between flavors.

**Production setup (one-time):**

1. Create `lib/data/programs_local.dart` (already git-ignored):
   ```bash
   cp lib/data/programs_example.dart lib/data/programs_local.dart
   ```
2. Edit `programs_local.dart` with your real programs.
3. Point `programs_production.dart` at your private file and freeze it from git:
   ```bash
   git update-index --skip-worktree lib/data/programs_production.dart
   ```
   Then change the one export line in `programs_production.dart`:
   ```dart
   export 'programs_local.dart';   // was: programs_example.dart
   ```

After this, `flutter run --flavor production` uses your private programs; all other flavors and `flutter test` continue using the example programs unchanged.

**Build commands:**

```bash
flutter build apk --flavor dev          # example programs
flutter build apk --flavor staging      # example programs
flutter build apk --flavor production   # private programs
flutter build appbundle --flavor production
```

`programs_example.dart` is the checked-in reference that documents every supported field and exercise type.

To add a program, append a `Program(...)` entry to the `programs` list in `programs_local.dart`. Each program needs a unique `id`. Exercises support:

| Field | Purpose |
|---|---|
| `type` | `timed` · `reps` · `instruction` · `steps` |
| `frequency` | `daily` · `nTimesPerWeek` (shown on scheduled training days) |
| `unilateral: true` | App runs left side then right side within each set |
| `hasWeight: true` | Enables weight tracking and progressive overload |
| `phase: 1–4` | Groups exercises into two-week phases with an in-app selector |
| `prepDurationSeconds` | Override the prep countdown (default: 3 s, 5 s for weighted) |

## Key commands

```bash
flutter analyze          # lint — must be clean before committing
flutter test             # run all tests
flutter build apk        # Android APK
flutter build web        # web build
```
