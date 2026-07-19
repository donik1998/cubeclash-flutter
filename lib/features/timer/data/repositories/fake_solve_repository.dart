import 'dart:async';
import 'dart:math';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/page.dart';
import '../../domain/entities/penalty.dart';
import '../../domain/entities/solve.dart';
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
  FakeSolveRepository({Random? random, DateTime? now})
      : _random = random ?? Random(7),
        _now = now ?? DateTime.now() {
    _history = _seedHistory();
  }

  final Random _random;
  final DateTime _now;

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
  }) async {
    await Future<void>.delayed(_latency);
    final Solve solve = Solve(
      id: clientId,
      event: event,
      scramble: scramble,
      timeMs: timeMs,
      solvedAt: solvedAt,
      penalty: penalty,
    );
    _session.add(solve);
    _history.insert(0, solve);
    _emitSession();
    return Ok<Solve>(solve);
  }

  @override
  Future<Result<Solve>> updatePenalty(String id, Penalty penalty) async {
    await Future<void>.delayed(_latency);

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
    await Future<void>.delayed(_latency);
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
    await Future<void>.delayed(_latency);

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

  /// ~140 solves over the past three weeks, slowly improving.
  List<Solve> _seedHistory() {
    final GenerateScramble generate = GenerateScramble(random: _random);
    final List<Solve> solves = <Solve>[];

    const int days = 21;
    for (int dayAgo = days; dayAgo >= 0; dayAgo--) {
      // Some days you don't cube.
      if (_random.nextDouble() < 0.15) continue;

      final int count = 4 + _random.nextInt(8);
      // Mean drifts from ~15.5s down to ~12.0s across the window — a believable
      // three weeks of practice rather than a flat random walk.
      final double progress = (days - dayAgo) / days;
      final double meanMs = 15500 - (3500 * progress);

      for (int i = 0; i < count; i++) {
        final DateTime solvedAt = _now.subtract(
          Duration(days: dayAgo, hours: _random.nextInt(6), minutes: i * 3),
        );

        solves.add(
          Solve(
            id: 'seed-$dayAgo-$i',
            event: '3x3',
            scramble: generate(),
            timeMs: _sampleTimeMs(meanMs),
            solvedAt: solvedAt,
            penalty: _samplePenalty(),
          ),
        );
      }
    }

    // Newest first, matching `GET /solves`.
    solves.sort((Solve a, Solve b) => b.solvedAt.compareTo(a.solvedAt));
    return solves;
  }

  /// A right-skewed time around [meanMs]: most solves cluster, a few are much
  /// slower (a bad OLL case), none are impossibly fast.
  int _sampleTimeMs(double meanMs) {
    // Sum of two uniforms ≈ triangular, then a long tail on 8% of solves.
    final double base =
        meanMs * (0.78 + (_random.nextDouble() + _random.nextDouble()) * 0.22);
    final double tail =
        _random.nextDouble() < 0.08 ? _random.nextDouble() * meanMs * 0.6 : 0;
    return (base + tail).round().clamp(6000, 60000);
  }

  Penalty _samplePenalty() {
    final double roll = _random.nextDouble();
    if (roll < 0.04) return Penalty.plus2;
    if (roll < 0.055) return Penalty.dnf;
    return Penalty.none;
  }

  /// Releases the session stream. Called from DI teardown in tests.
  Future<void> dispose() => _sessionController.close();
}
