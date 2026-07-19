# 🧊 CubeClash — Flutter App

The primary client for **CubeClash**, a competitive speedcubing app: solo WCA timer + live 1v1 races. Cross-platform (iOS + Android) from a single Dart codebase.

## Stack
- **Framework:** Flutter · Dart
- **Architecture:** Clean Architecture, feature-first (presentation → domain → data)
- **State:** BLoC / Cubit
- **DI:** get_it + injectable
- **Routing:** go_router (StatefulShellRoute, 4-tab shell)
- **Networking:** Dio (JWT interceptor + refresh)
- **Local store:** Drift / SQLite (offline-first)
- **Real-time:** socket_io_client (live races)
- **Analytics:** PostHog · **Errors:** Crashlytics

## Backend
Talks to `cubeclash-backend` (NestJS REST + WebSocket).

## Getting started

This repo ships the app architecture (`lib/`), tests, CI, and the generated native
folders (`android/`, `ios/`). To run:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

To regenerate the native folders (does **not** overwrite existing files):

```bash
flutter create --project-name cubeclash --org com.donik1998 --platforms android,ios .
```

Quality gate (matches CI):

```bash
dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test
```

## Project structure

```
lib/
  core/      theme · router · network · realtime · analytics · di · error · widgets
  features/  timer · race · stats · profile   (presentation · domain · data)
  app.dart · main.dart
test/        unit (WCA averaging) + widget smoke test
```

See `CLAUDE.md` for architecture, conventions, and the backend contract.

## Status
🚧 **Scaffolding.** Architecture skeleton + tested WCA averaging in place; the
timer/race/stats/profile shell runs. Feature logic (timer state machine, race
flow, offline sync) is next.

## License
MIT © 2026 Doniyor Murodkulov

> Working title — repo may be renamed once the product name is finalized.
