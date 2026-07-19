# CubeClash — Flutter Client (project memory)

Guidance for Claude Code working in this repo. This is the **primary client**
(`cubeclash-flutter`) of the CubeClash system. Full specs live in the Obsidian
vault (**Path to Big Tech → CubeClash**). Keep this file in sync as the app grows.

## What this is

CubeClash: a competitive speedcubing app — solo WCA timer + live 1v1 races +
stats/leaderboards. Portfolio centerpiece to prove **backend + real-time systems
depth**, not just Flutter delivery. One of four repos:

- `cubeclash-backend` — TypeScript · NestJS · PostgreSQL/Prisma · Redis · Socket.IO (source of truth; built first)
- `cubeclash-flutter` — **this repo** (primary client, v1)
- `cubeclash-ios` / `cubeclash-android` — native v2 (build **one** platform, deep)

Same Clean Architecture across every client; same backend contract.

## Architecture — feature-first Clean Architecture

Dependencies point inward: **presentation → domain ← data**.

- `presentation/` — widgets + BLoC/Cubit. Renders state, dispatches events. No business logic.
- `domain/` — pure Dart: entities, use cases, repository interfaces. **No Flutter/IO imports** (keep it unit-testable).
- `data/` — repository implementations + data sources (remote: Dio, local: Drift). Maps DTOs ↔ entities.

## Folder map

```
lib/
  core/       theme · router · network · realtime · analytics · di · error · widgets
  features/<feature>/  presentation · domain · data
  app.dart · main.dart
assets/fonts/ Noto Serif (bundled variable font)
test/
  support/harness.dart      themed pump helpers + golden helper
  **/goldens/*.png          goldens live next to their test file
```

Current state (Phases A–B complete):

- **Component library** (`core/widgets`) — built, golden-tested light + dark.
- **Timer feature** — complete. Local scrambler with move-cancellation rules,
  `TimerBloc` state machine (inspection +2/DNF boundaries, hold/tap styles),
  and all three screens (Home, Solve Detail, Session & History).
- **Stats feature** — complete. My Stats (PB cards + hand-painted progress and
  distribution charts), Leaderboards (scope/metric filters, cursor paging,
  pinned current-user row), Player Profile with head-to-head.
- **Race feature** — complete. `RaceBloc` over the `/race` gateway with
  disconnect, reconnect and idempotent-submit handling; lobby (quick/private/
  tournaments), matchmaking modal, ready room, full-screen live race and both
  result states.
- **You feature** — complete. Profile, Settings (persisted via
  shared_preferences; theme is bound to `SettingsCubit` above `MaterialApp`)
  and Friends. `feature_placeholder.dart` is gone — all four tabs are real.

Backend access is stubbed. Every repository ships a `Fake…` and a real impl;
`kUseFakeData` in `injection.dart` picks one.

## Conventions

- Package name is `cubeclash` → import `package:cubeclash/...`.
- **State:** flutter_bloc — Cubit for simple screens, Bloc for the timer/race state machines.
- **DI:** get_it, wired manually in `core/di/injection.dart`. Upgrade to injectable codegen later.
- **Routing:** go_router `StatefulShellRoute` (4-tab shell) in `core/router`. Immersive flows (running solve, live race) become full-screen routes outside the shell.
- **Networking:** Dio + `AuthInterceptor` (JWT attach + refresh-on-401). Base URL via `--dart-define=API_BASE_URL`. REST base is `/v1`, fields are `snake_case`.
- **Real-time:** `RaceGateway` is an *interface*; `SocketRaceGateway` wraps socket_io_client on `/race`, `FakeRaceGateway` scripts the whole lifecycle (opponent included) so races are demoable with no backend. Both emit identical events in identical order, so `RaceBloc` can't tell them apart. `RaceBloc` is a **singleton** — a race outlives the lobby widget, since Live Race is its own route.
- **The server owns competitive truth.** The Race bloc never compares two times, picks a winner, or computes an Elo change; it renders `race:result`. Same rule for `is_pb` and leaderboard rank.
- **Settings** live in `SettingsCubit`, a **singleton provided above `MaterialApp`** (the theme is one of its values) and loaded in `main()` before the first frame so the app never flashes the wrong theme. Every change writes through immediately — no save button. The Timer screen listens and forwards `timerPreferences` to `TimerBloc`.
- **Tests that touch settings** must register `InMemorySettingsRepository` (test/support) — `shared_preferences` goes through a platform channel that never answers under `flutter test`, so a write just hangs.
- **Theming:** design tokens in `core/theme` (`AppColors` light/dark, `AppSpacing`, `AppRadius`, `AppTypography`). Read colors via `context.colors`, type via `AppTypography.<scale>`. **Never hardcode colors/spacing/type — use tokens.**
- **Typography:** Noto Serif is a **bundled variable font** (`assets/fonts`, declared in pubspec). google_fonts was removed — it fetches at runtime, which means FOUT, a hard failure offline, and it refuses to render under `flutter test` (breaking goldens). Live-updating numbers must use `.tabular`.
- **Components:** the shared library lives in `core/widgets`, imported via the `widgets.dart` barrel. Compose screens from it — don't re-roll buttons/chips/cards per feature.
- **Every async screen ships loading + empty + error** (`LoadingState` / `EmptyState` / `ErrorState`). Not just the happy path.
- **Offline:** the Solves repository is local-first (Drift); reconcile via `POST /sync` (last-write-wins by `updated_at` + `client_id`). Not built yet — the vault marks full offline sync as fast-follow, not MVP, so `SolveRepositoryImpl` keeps an in-memory session mirror behind the streaming `watchSession()` seam Drift will slot into.
- **Errors:** repositories return `Result<T>` (`Ok`/`Err` in `core/error/result.dart`), never throw. Presentation switches over it exhaustively. Cursor pages use `Page<T>` (`{items, next_cursor}`).
- **Fake vs real data:** every feature defines its repository interface against the documented API, then ships `FakeXRepository` (seeded, realistic) **and** `XRepositoryImpl` (Dio). `kUseFakeData` (`--dart-define=USE_FAKE_DATA=false`) switches them. Fakes never invent server-owned fields (`is_pb`, `elo`, rank).
- **Charts** are hand-painted `CustomPainter`s in the owning feature — no chart
  package. They draw in on load and fall back to an instant render when
  `MediaQuery.disableAnimations` is set. The progress chart's **y-axis is
  inverted**: faster is up.
- **Time-driven blocs** take a `Ticker` (`core/util/ticker.dart`); tests inject `FakeTicker` to hit exact boundaries without sleeping.
- **Immersive flows:** the running solve hides shell chrome via `ImmersiveController` (a `ValueNotifier<bool>` the shell watches) rather than a route push — same nav-safety, no navigation on the latency-critical press. The Live Race *is* a real full-screen route.
- **Tests:** call `initTestFonts()` in `setUpAll` — without it `flutter test` renders every icon and glyph as a box. Use `harness()` for components, `harnessPage()` for full screens (a page needs a bounded viewport).
- **Analytics:** `AnalyticsService` (no-op default). Authoritative events fire server-side; UI events client-side.

## Design tokens (source: Obsidian → Design System)

Brand blue `#2E6BFF` (light) / `#4C82FF` (dark); WCA cube colors constant across
themes; Noto Serif throughout. Spacing 4–64, radius sm8/md12/lg16/xl20/pill.
Active nav tab = `brand/primary-soft` pill. Signature nav motion is **Variant C**
(pinch-squeeze + directional icon tilt) — TODO in `ScaffoldWithNavBar`.

## Backend contract (see `cubeclash-backend`, Obsidian API Design + Real-time Race Protocol)

- **REST:** `/auth/*`, `/me`, `/solves`, `/sync`, `/scramble`, `/leaderboard`, `/races`. JWT (~15m access + ~30d refresh, rotation). Error shape `{ error: { code, message, details } }`. Cursor pagination.
- **WS (`/race`):** client → `race:create|join|ready`, `solve:start|stop`; server → `race:state|countdown|scramble|opponent_progress|result`. Server-authoritative; room state in Redis.

## Commands

- Install: `flutter pub get`
- Run: `flutter run --dart-define=API_BASE_URL=http://localhost:3000`
- Format: `dart format .`
- Analyze: `flutter analyze`
- Test: `flutter test`
- Quality gate (matches CI): `dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test`

## Getting started — generate native platform folders

This scaffold intentionally ships without `android/`, `ios/`, etc. Generate them
with your local SDK (this does **not** overwrite existing files):

```
flutter create --project-name cubeclash --org com.donik1998 --platforms android,ios .
flutter pub get
dart format .
flutter run
```

## Repo tooling — `.claude/`

Claude Code configuration for this repo:

- **`settings.json`** — *shared, committed.* Baseline anyone working in the repo inherits (currently: allow `flutter` / `dart` commands).
- **`settings.local.json`** — *personal, git-ignored.* Your machine-local permission scope — an allow / ask / deny list that lets the agent run project dev commands (flutter, dart, git, common shell tools) and edit files **without a prompt each time, bounded to this project**. Consequential actions (`git push`, `gh`) are set to *ask*; destructive ones (`sudo`, `rm -rf`, force-push, `reset --hard`) are *denied*. Widen or tighten it as you like — it never leaves your machine.
- **`commands/`** — *shared, committed.* Slash commands: `/scaffold-feature`, `/run-checks`.

## Roadmap (post-MVP)

CV camera timer (flagship v1.1, doubles as PvP anti-cheat), full offline sync,
ranked matchmaking (Elo/Glicko), tournaments, more events, daily challenge,
native v2, smart-cube (BLE).

## Don'ts

- Don't put business logic in presentation, or Flutter/IO imports in domain.
- Don't hardcode colors/spacing — use the design tokens.
- Don't trust client-computed competitive fields (`is_pb`, `elo`, rank) — the server owns them.
