import 'dart:async';
import 'dart:math';

import '../../../../core/demo/demo_seed.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/page.dart';
import '../../domain/entities/penalty.dart';
import '../../domain/entities/solve.dart';
import '../../domain/entities/wca_event.dart';
import '../../domain/repositories/solve_repository.dart';
import '../../domain/usecases/generate_scramble.dart';

/// In-memory [SolveRepository] seeded with plausible speedcubing data.
///
/// **Why this exists.** `cubeclash-backend` is not built yet. Rather than stub
/// the architecture (or block the whole client on the server), every feature
/// ships two implementations of its real repository interface and picks one in
/// `injection.dart` behind `kUseFakeData`. The app is fully demoable today and
/// flipping one `--dart-define` moves it to the live backend.
///
/// The data is deliberately realistic — times clustered in a believable range
/// with a plausible spread, an occasional +2 and rarer DNF, and a slow
/// improvement trend over the history so the Stats charts have something true
/// to draw.
///
/// Note what it does **not** fake: `is_pb`. That field is server-owned
/// (docs → API Design) and is not invented here.
class FakeSolveRepository implements SolveRepository {
  FakeSolveRepository(
      {Random? random, DateTime? now, double readFailureRate = 0})
      : _random = random ?? Random(7),
        _now = now ?? DateTime.now(),
        _readFailureRate = readFailureRate {
    _history = _seedHistory();
  }

  final Random _random;
  final DateTime _now;

  /// How often [getHistory] pretends the network failed, so the error state is
  /// reachable in a demo. Defaults to 0; wire a small value in DI to show it.
  final double _readFailureRate;

  /// Everything ever solved, newest first — what `GET /solves` would return.
  late final List<Solve> _history;

  /// The current session. Starts empty: a fresh app launch is a fresh session,
  /// which also means the Timer screen's empty state is reachable in the demo.
  final List<Solve> _session = <Solve>[];

  final StreamController<List<Solve>> _sessionController =
      StreamController<List<Solve>>.broadcast();

  /// Simulated latency, so loading states are actually visible in the demo
  /// rather than flashing past in a single frame.
  static const Duration _latency = Duration(milliseconds: 220);

  static const int _pageSize = 20;

  Future<void> _wait() => Future<void>.delayed(demoLatency(_latency, _random));

  @override
  Stream<List<Solve>> watchSession() async* {
    yield List<Solve>.unmodifiable(_session);
    yield* _sessionController.stream;
  }

  void _emitSession() =>
      _sessionController.add(List<Solve>.unmodifiable(_session));

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
    await _wait();
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
    _history.insert(0, solve);
    _emitSession();
    return Ok<Solve>(solve);
  }

  @override
  Future<Result<Solve>> updatePenalty(String id, Penalty penalty) async {
    await _wait();

    final int sessionIndex = _session.indexWhere((Solve s) => s.id == id);
    final int historyIndex = _history.indexWhere((Solve s) => s.id == id);
    if (sessionIndex == -1 && historyIndex == -1) {
      return const Err<Solve>(CacheFailure('That solve no longer exists.'));
    }

    final Solve source =
        sessionIndex != -1 ? _session[sessionIndex] : _history[historyIndex];
    final Solve updated = source.copyWith(penalty: penalty);

    if (sessionIndex != -1) {
      _session[sessionIndex] = updated;
      _emitSession();
    }
    if (historyIndex != -1) _history[historyIndex] = updated;

    return Ok<Solve>(updated);
  }

  @override
  Future<Result<void>> deleteSolve(String id) async {
    await _wait();
    final bool existed = _session.any((Solve s) => s.id == id) ||
        _history.any((Solve s) => s.id == id);
    if (!existed) {
      return const Err<void>(CacheFailure('That solve no longer exists.'));
    }
    _session.removeWhere((Solve s) => s.id == id);
    _history.removeWhere((Solve s) => s.id == id);
    _emitSession();
    return const Ok<void>(null);
  }

  @override
  Future<Result<Page<Solve>>> getHistory({
    String event = '3x3',
    String? cursor,
  }) async {
    await _wait();
    if (_random.nextDouble() < _readFailureRate) {
      return const Err<Page<Solve>>(
        NetworkFailure('Something went wrong. Pull to retry.'),
      );
    }

    final List<Solve> forEvent =
        _history.where((Solve s) => s.event == event).toList();

    // The cursor is simply the index to resume from — an opaque token to the
    // caller, which is all the real API guarantees too.
    final int start = int.tryParse(cursor ?? '0') ?? 0;
    final int end = (start + _pageSize).clamp(0, forEvent.length);
    if (start >= forEvent.length) {
      return const Ok<Page<Solve>>(Page<Solve>(items: <Solve>[]));
    }

    return Ok<Page<Solve>>(
      Page<Solve>(
        items: forEvent.sublist(start, end),
        nextCursor: end < forEvent.length ? '$end' : null,
      ),
    );
  }

  @override
  Future<Result<void>> clearSession() async {
    _session.clear();
    _emitSession();
    return const Ok<void>(null);
  }

  /// A three-week practice history for every **timed** event, newest first.
  ///
  /// The times come from the shared [generateDemoHistory] seeder rather than a
  /// local sampler, so that `FakeStatsRepository` — which reads the same seeder
  /// — reports bests and averages that actually match the solves listed here.
  /// Fewest Moves and Multi-Blind are excluded (they are not ranked on a clock;
  /// see the seeder's doc), so their history stays empty in the demo.
  List<Solve> _seedHistory() {
    final GenerateScramble generate = GenerateScramble(random: _random);
    final List<Solve> solves = <Solve>[];

    for (final String eventId in demoTimedEvents.keys) {
      final WcaEvent event = WcaEvent.fromId(eventId);
      final List<DemoSolveSample> samples =
          generateDemoHistory(eventId, now: _now);

      for (int i = 0; i < samples.length; i++) {
        final DemoSolveSample sample = samples[i];
        solves.add(
          Solve(
            id: 'seed-$eventId-$i',
            event: eventId,
            // A fresh scramble per solve — every timed event now has a real
            // scrambler (Clock and Megaminx included), so none of these seed an
            // empty string.
            scramble: generate.scrambleFor(event).text,
            timeMs: sample.timeMs,
            solvedAt: sample.solvedAt,
            penalty: _penaltyFrom(sample.penalty),
          ),
        );
      }
    }

    // Newest first, matching `GET /solves`.
    solves.sort((Solve a, Solve b) => b.solvedAt.compareTo(a.solvedAt));
    return solves;
  }

  Penalty _penaltyFrom(DemoPenalty penalty) => switch (penalty) {
        DemoPenalty.none => Penalty.none,
        DemoPenalty.plus2 => Penalty.plus2,
        DemoPenalty.dnf => Penalty.dnf,
      };

  /// Releases the session stream. Called from DI teardown in tests.
  Future<void> dispose() => _sessionController.close();
}
