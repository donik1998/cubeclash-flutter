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

Current state — **all phases (A–H) complete**, 382 tests green:

- **Component library** (`core/widgets`) — built, golden-tested light + dark.
- **Timer feature** — complete, across **all 17 WCA events**. Local scrambler
  with move-cancellation rules (2×2 … 7×7), `TimerBloc` state machine
  (inspection +2/DNF boundaries, hold/tap styles), and all three screens
  (Home, Solve Detail, Session & History). See **Event model** below.
- **Stats feature** — complete. My Stats (PB cards + hand-painted progress and
  distribution charts), Leaderboards (scope/metric filters, cursor paging,
  pinned current-user row), Player Profile with head-to-head.
- **Race feature** — complete, event-aware. `RaceBloc` over the `/race` gateway with
  disconnect, reconnect and idempotent-submit handling; lobby (quick/private/
  tournaments), matchmaking modal, ready room, full-screen live race and both
  result states.
- **You feature** — complete. Profile, Settings (persisted via
  shared_preferences; theme is bound to `SettingsCubit` above `MaterialApp`)
  and Friends. `feature_placeholder.dart` is gone — all four tabs are real.
- **Auth feature** — complete. Welcome → sign up → log in → profile setup,
  secure token storage, a real refresh-on-401 flow, and a go_router guard.

Backend access is stubbed. Every repository ships a `Fake…` and a real impl;
`kUseFakeData` in `injection.dart` picks one.

## Event model — all 17 WCA events

Source of truth is **WCA Regulations §9b / §9f**, verified July 2026. The
regulation numbers are quoted in `event_format.dart` and asserted in
`test/features/timer/wca_event_test.dart`, so an edit that contradicts them
fails with a pointer to the authority.

- **`WcaEvent`** (`timer/domain/entities/wca_event.dart`) is the catalogue —
  seventeen constants, each carrying its id, competition format, result kind,
  puzzle, notation, icon composition and raceability. Everything else reads
  from it. `WcaEvent.fromId` is **lenient**: an unknown id falls back to 3×3
  rather than throwing, because a server that grows an eighteenth event before
  the client does must not crash the timer.
- **Event ids extend the ones already in the database** — `3x3`, `4x4`, then
  `3x3-oh`, `4x4-bld`, `3x3-fmc`, `3x3-mbld`. Not the WCA's `333`/`444` codes:
  switching would orphan every solve already written.
- **A scramble is `Scramble`, not `String`.** Lines of tokens, because three
  notations lose meaning when flattened: **Megaminx** line breaks are semantic
  (cubers execute it line by line), **Square-1** is slash-separated with no
  spaces to wrap on, and **Multi-Blind** is N independent scrambles.
  **The wire format stays a plain string** — newline-separated, exactly what
  TNoodle emits — so `Solve.scramble`, `POST /solves` and `race:scramble` did
  not change and the backend does not have to know about notation. The one new
  guarantee: **`\n` is significant and must round-trip.**
- **A result is `SolveResult`, not just `timeMs`.** `Solve.timeMs` still means
  the attempt's duration for every event (FMC and Multi-Blind are timed too),
  but for those two it is not the *result*: `Solve` gains nullable
  `moveCount` / `solvedCount` / `attemptedCount`, and `POST /solves` gains
  three optional fields. Rank on `Solve.rankingValue`, never on `timeMs`.
  Multi-Blind ranks by **points then time** (9f12) and auto-DNFs below two
  solved cubes — `SolveResult.compareTo` owns that, not any caller.
- **Averaging is per-event.** `EventFormat.sessionStats` picks the three cards:
  3×3 keeps `best · ao5 · ao12`; 6×6/7×7/FMC read `best · mo3 · ao5`;
  blindfolded reads the same (9b3a ranks on best, 9b3b also recognises a mo3);
  Multi-Blind reads `best · last · solves` because averaging attempts of
  different cube counts is meaningless. **The competition format leads and the
  practice statistic follows** — a solo timer is asked both questions.
- **`+2` is a time penalty only.** The chip is hidden for FMC and Multi-Blind
  rather than offered as a button that would lie. **A DNF applies to every
  event.**
- **WCA precision (9f1/9f2)** lives in `core/util/time_format.dart`, shared by
  `TimeText` and the domain's `FormatResult` because neither layer may import
  the other. Under 10 min → hundredths; 10 min and over, and all Multi-Blind
  → seconds; an hour and over → `1:04:22`.
- **Scramblers: twelve of seventeen.** The six NxN cubes, plus the six
  modifier events which reuse their base puzzle's scrambler. Megaminx,
  Pyraminx, Skewb, Square-1 and Clock render an explicit **"scrambles coming"**
  state — each needs its own notation and a random-state solver (roadmap).
  `GenerateScramble.scrambleFor` returns `Scramble.empty` for those; it never
  substitutes a 3×3 scramble under another event's label.
- **Icons compose**: base `PuzzleFamily` shape + `PuzzleModifier` badge, not
  seventeen bespoke files. Seventeen events are eleven puzzles and five
  disciplines, and `3BLD` should read as a 3×3 because it is one. The
  domain↔widget mapping lives in `event_picker_sheet.dart` (`shapeFor` /
  `badgeFor`), since `core/widgets` must not know about events and the domain
  must not import Flutter.
- **FMC and Multi-Blind enter their result by hand** (`ManualResultSheet`).
  FMC disables the touch surface entirely — there is no stopwatch result to
  capture. Multi-Blind stops the clock, then asks, and **does not write the
  solve until it is answered**: a Multi-Blind row without its cube counts is
  not a partial record, it is a meaningless one.
- **Raceable events** are every NxN plus One-Handed. Blindfolded is excluded
  because the memorisation phase is inside the timed attempt and nothing on
  screen can tell it from stalling; FMC and Multi-Blind because their results
  are not a clock. **Quick match is narrower still** — 2×2, 3×3, OH — because
  a `6x6 quick match` queue is realistically empty; everything else raceable is
  private-room only. The fake gateway's opponent pace and progress cadence
  scale with the event (10 Hz short, 4 Hz long).

## Conventions

- Package name is `cubeclash` → import `package:cubeclash/...`.
- **State:** flutter_bloc — Cubit for simple screens, Bloc for the timer/race state machines.
- **DI:** get_it, wired manually in `core/di/injection.dart`. Upgrade to injectable codegen later.
- **Routing:** go_router `StatefulShellRoute` (4-tab shell) in `core/router`. The router is **built by DI** (`AppRouter.create(tokens)`), not a static — it captures the `TokenStore` it guards on, so a process-wide instance would outlive its store. A `redirect` guard sends signed-out users to `/auth` and signed-in users out of it; it waits on `TokenStore.isRestored` so a cold start doesn't flash the welcome screen at someone already signed in.
- **Networking:** Dio + `AuthInterceptor`. Refresh-on-401 is **single-flight** — concurrent 401s share one refresh, because token rotation means a second refresh would present an already-dead token and sign the user out during a recoverable blip. A retry is flagged so its own 401 can't loop. Refresh goes through a *separate* un-intercepted Dio. Base URL via `--dart-define=API_BASE_URL`; REST base `/v1`, `snake_case`.
- **Tokens** live in `TokenStore` (in memory for synchronous header attach, written through to `flutter_secure_storage`). It is a `ChangeNotifier` — the router's guard redirects off its notifications, which is how a dead session bounces the user out.
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
(pinch-squeeze + directional icon tilt) — implemented in `ScaffoldWithNavBar`,
driven from one `AnimationController` per tab change, with a reduce-motion
fallback.

**Known a11y finding:** `text/muted` is ~2.5:1 on `bg/canvas`, below the 4.5:1
WCAG AA body threshold, in both themes. The token comes from the design system,
so it's a design decision to revisit rather than something to patch in code.
Until it changes, **muted text is decorative only** — it never carries
information a user needs to operate the app. `test/core/theme/contrast_test.dart`
encodes this and will tell you to tighten it if the token is ever darkened.

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

## Pending work — prompts

One piece is specced but not built, written to be pasted into a fresh session
(see §9 of `IMPLEMENTATION_PROMPT.md` — one phase per session):

- **`PROMPT_RACE_FIGMA.md`** — the Race screens were built before the Figma MCP
  was reachable and don't match the frames. Live Race in particular is a
  different screen (two side-by-side player cards with `VS`, no hero timer, no
  progress bars). Presentation layer only; `RaceBloc` stays as-is.

**`PROMPT_WCA_EVENTS.md` is done** — see **Event model** above. What it
deliberately scoped out is the next piece of work: per-puzzle **random-state**
scramblers for Megaminx, Pyraminx, Skewb, Square-1 and Clock, each of which
needs its own notation and, for competition legality, a solver.

## Roadmap (post-MVP)

CV camera timer (flagship v1.1, doubles as PvP anti-cheat), full offline sync,
ranked matchmaking (Elo/Glicko), tournaments, random-state WCA-legal
scramblers for the five remaining puzzles, daily challenge, native v2,
smart-cube (BLE).

## Don'ts

- Don't put business logic in presentation, or Flutter/IO imports in domain.
- Don't hardcode colors/spacing — use the design tokens.
- Don't trust client-computed competitive fields (`is_pb`, `elo`, rank) — the server owns them.
