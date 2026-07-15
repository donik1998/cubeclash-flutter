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

## Status
🚧 **Scaffolding.** Design system + all MVP screens complete in Figma; implementation starting.

## License
MIT © 2026 Doniyor Murodkulov

> Working title — repo may be renamed once the product name is finalized.
