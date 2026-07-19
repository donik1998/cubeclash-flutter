---
description: Scaffold a new feature module (presentation/domain/data) following CubeClash Clean Architecture.
argument-hint: <feature_name>
---

Create a new feature module named `$ARGUMENTS` under `lib/features/$ARGUMENTS/`,
following the project's feature-first Clean Architecture (see `CLAUDE.md`):

- `domain/entities/` — pure Dart entities (Equatable), no Flutter/IO imports.
- `domain/repositories/` — abstract repository interface(s).
- `domain/usecases/` — one class per use case.
- `data/models/` — DTOs with `fromJson`/`toJson`, mapping to/from entities.
- `data/datasources/` — remote (Dio) + local (Drift) sources.
- `data/repositories/` — repository implementation(s).
- `presentation/bloc/` — Bloc/Cubit + state (flutter_bloc).
- `presentation/pages/` — screens.
- `presentation/widgets/` — feature-scoped widgets.

Then:
1. Register dependencies in `lib/core/di/injection.dart`.
2. Add a route/branch in `lib/core/router/app_router.dart` if it needs a screen.
3. Add a unit test under `test/features/$ARGUMENTS/` for the domain logic.

Keep the domain layer free of Flutter imports. Use design tokens (`context.colors`,
`AppSpacing`, `AppRadius`) — never hardcode colors or spacing.
