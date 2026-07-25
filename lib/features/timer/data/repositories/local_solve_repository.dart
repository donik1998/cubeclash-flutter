import 'dart:async';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/page.dart';
import '../../domain/entities/penalty.dart';
import '../../domain/entities/solve.dart';
import '../../domain/repositories/solve_repository.dart';
import '../local/local_solve_store.dart';

/// A [SolveRepository] that persists to the device via [LocalSolveStore] —
/// **the no-backend build's real store**, not a demo.
///
/// It is the counterpart to `FakeSolveRepository`: that one seeds a plausible
/// history and forgets it on exit (for goldens and screenshots); this one keeps
/// nothing it wasn't given and remembers everything across a relaunch. DI picks
/// between them with `USE_LOCAL_STORE` — the shipping app persists, the
/// deterministic seed is opt-out for tests.
///
/// **Session and history are the same list here.** With no backend there is no
/// server-side `solves` history to fall back on, so the persisted session *is*
/// the history [getHistory] pages over — and ending a session (`clearSession`)
/// genuinely clears it locally. When `SolveRepositoryImpl` lands, server history
/// outlives a local clear; until then, local is all there is.
class LocalSolveRepository implements SolveRepository {
  LocalSolveRepository(this._store);

  final LocalSolveStore _store;

  /// The session, oldest first — mirrors the persisted list once hydrated.
  final List<Solve> _session = <Solve>[];

  final StreamController<List<Solve>> _sessionController =
      StreamController<List<Solve>>.broadcast();

  /// Hydration runs once, lazily, on first access — memoised so concurrent
  /// callers share the single disk read rather than racing it.
  Future<void>? _hydration;

  static const int _pageSize = 20;

  Future<void> _ensureHydrated() async {
    _hydration ??= _hydrate();
    await _hydration;
  }

  Future<void> _hydrate() async {
    final List<Solve> loaded = await _store.loadSession();
    _session
      ..clear()
      ..addAll(loaded);
  }

  void _emitSession() =>
      _sessionController.add(List<Solve>.unmodifiable(_session));

  Future<void> _persist() => _store.saveSession(_session);

  @override
  Stream<List<Solve>> watchSession() async* {
    await _ensureHydrated();
    yield List<Solve>.unmodifiable(_session);
    yield* _sessionController.stream;
  }

  @override
  Future<Result<Solve>> addSolve({
    required String event,
    required String scramble,
    required int timeMs,
    required Penalty penalty,
    required DateTime solvedAt,
    required String clientId,
    int? moveCount,
    int? solvedCount,
    int? attemptedCount,
  }) async {
    await _ensureHydrated();
    final Solve solve = Solve(
      id: clientId,
      event: event,
      scramble: scramble,
      timeMs: timeMs,
      solvedAt: solvedAt,
      penalty: penalty,
      moveCount: moveCount,
      solvedCount: solvedCount,
      attemptedCount: attemptedCount,
    );
    _session.add(solve);
    await _persist();
    _emitSession();
    return Ok<Solve>(solve);
  }

  @override
  Future<Result<Solve>> updatePenalty(String id, Penalty penalty) async {
    await _ensureHydrated();
    final int index = _session.indexWhere((Solve s) => s.id == id);
    if (index == -1) {
      return const Err<Solve>(CacheFailure('That solve no longer exists.'));
    }
    final Solve updated = _session[index].copyWith(penalty: penalty);
    _session[index] = updated;
    await _persist();
    _emitSession();
    return Ok<Solve>(updated);
  }

  @override
  Future<Result<void>> deleteSolve(String id) async {
    await _ensureHydrated();
    final bool existed = _session.any((Solve s) => s.id == id);
    if (!existed) {
      return const Err<void>(CacheFailure('That solve no longer exists.'));
    }
    _session.removeWhere((Solve s) => s.id == id);
    await _persist();
    _emitSession();
    return const Ok<void>(null);
  }

  @override
  Future<Result<Page<Solve>>> getHistory({
    String event = '3x3',
    String? cursor,
  }) async {
    await _ensureHydrated();
    final List<Solve> forEvent = _session
        .where((Solve s) => s.event == event)
        .toList()
      ..sort((Solve a, Solve b) => b.solvedAt.compareTo(a.solvedAt));

    // The cursor is the index to resume from — opaque to the caller, exactly
    // as the real API's is.
    final int start = int.tryParse(cursor ?? '0') ?? 0;
    if (start >= forEvent.length) {
      return const Ok<Page<Solve>>(Page<Solve>(items: <Solve>[]));
    }
    final int end = (start + _pageSize).clamp(0, forEvent.length);

    return Ok<Page<Solve>>(
      Page<Solve>(
        items: forEvent.sublist(start, end),
        nextCursor: end < forEvent.length ? '$end' : null,
      ),
    );
  }

  @override
  Future<Result<void>> clearSession() async {
    await _ensureHydrated();
    _session.clear();
    await _persist();
    _emitSession();
    return const Ok<void>(null);
  }

  /// Releases the session stream. Called from DI teardown in tests.
  Future<void> dispose() => _sessionController.close();
}
