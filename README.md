# 🧊 CubeClash — Flutter App

The primary client for **CubeClash**, a competitive speedcubing app: solo WCA timer + live 1v1 races. Cross-platform (iOS + Android) from a single Dart codebase.

## Stack
- **Framework:** Flutter · Dart
- **Architecture:** Clean Architecture, feature-first (presentation → domain → data)
- **State:** BLoC / Cubit
- **DI:** get_it (manual; injectable codegen later)
- **Routing:** go_router (StatefulShellRoute, 4-tab shell + auth guard)
- **Networking:** Dio (JWT attach + single-flight refresh-on-401)
- **Session:** flutter_secure_storage · **Preferences:** shared_preferences
- **Local store:** SharedPreferences (offline-first solves + session) — implemented
- **Real-time:** socket_io_client (live races)
- **Typography:** Noto Serif, bundled as a variable font
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
  core/      theme · router · network · realtime · analytics · di · error · util · widgets
  features/  timer · race · stats · profile · auth   (presentation · domain · data)
  app.dart · main.dart
assets/fonts/  Noto Serif (variable)
test/        unit · bloc · widget · golden (light + dark)
```

### Running without a backend

`cubeclash-backend` doesn't exist yet, so every feature ships two
implementations of its repository interface and picks one with a build flag.
Fake data is the default, so `flutter run` gives a fully working app —
including races, against a scripted opponent.

```bash
# demo (default)
flutter run

# against a live server
flutter run --dart-define=USE_FAKE_DATA=false \
            --dart-define=API_BASE_URL=https://api.cubeclash.app
```

See `CLAUDE.md` for architecture, conventions, and the backend contract.

## Status

✅ **All 19 screens built**, all 17 WCA events supported, 382 tests green.

| Phase | Scope | State |
|---|---|---|
| A | Shared component library + typography tokens | ✅ |
| B | Timer — local scrambler, `TimerBloc`, 3 screens | ✅ |
| C | Stats — My Stats, Leaderboards, Player Profile | ✅ |
| D | Race — `RaceBloc` over the `/race` gateway, 6 screens | ✅ |
| E | You — Profile, Settings, Friends, persisted prefs | ✅ |
| F | Auth — 4 screens, secure tokens, refresh, route guard | ✅ |
| G | Motion (nav Variant C), reduce-motion, a11y, goldens | ✅ |
| H | All 17 WCA events — event/result model, per-event formats, real scramblers for every event | ✅ |

**Events.** All seventeen are selectable, timed and tracked, with the
competition format from WCA Regulations §9b driving the session statistics, and
**every one produces a real, legal scramble** — the six NxN cubes and their six
modifier events (random-move), Megaminx and Clock (pattern), Pyraminx and Skewb
(verified random-state) and Square-1 (random-move). Solves and the selected
event persist across a relaunch (SharedPreferences), with no backend running.

**Next:** the backend (`cubeclash-backend`) — the client is done and waiting on
the REST/socket API. Then the uniform random-state Square-1 solver and the CV
camera timer.
Everything behind `kUseFakeData` becomes live the moment the backend answers —
the real repository implementations are already written against the documented
contract.

## License
MIT © 2026 Doniyor Murodkulov

> Working title — repo may be renamed once the product name is finalized.
