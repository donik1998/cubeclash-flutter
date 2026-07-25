import 'dart:async';
import 'dart:math';

import 'package:cubeclash/core/analytics/analytics_service.dart';
import 'package:cubeclash/core/error/result.dart';
import 'package:cubeclash/core/network/page.dart';
import 'package:cubeclash/features/timer/domain/entities/penalty.dart';
import 'package:cubeclash/features/timer/domain/entities/solve.dart';
import 'package:cubeclash/features/timer/domain/repositories/last_event_store.dart';
import 'package:cubeclash/features/timer/domain/repositories/solve_repository.dart';
import 'package:cubeclash/features/timer/domain/usecases/generate_scramble.dart';
import 'package:cubeclash/features/timer/presentation/bloc/timer_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// The timer reopens on the event the user left it on. These cover the bloc
/// side of that: it hydrates the stored event on start and writes back on every
/// change — and degrades to 3×3 when there is no store or the stored id is
/// stale, so a persisted preference can never crash the timer.
class _FakeLastEventStore implements LastEventStore {
  _FakeLastEventStore([this.value]);

  String? value;

  @override
  Future<String?> loadLastEvent() async => value;

  @override
  Future<void> saveLastEvent(String eventId) async => value = eventId;
}

/// Only [watchSession] is exercised by these tests; the rest are unreachable.
class _StubSolveRepository implements SolveRepository {
  @override
  Stream<List<Solve>> watchSession() async* {
    yield const <Solve>[];
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
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> clearSession() => throw UnimplementedError();

  @override
  Future<Result<void>> deleteSolve(String id) => throw UnimplementedError();

  @override
  Future<Result<Page<Solve>>> getHistory(
          {String event = '3x3', String? cursor}) =>
      throw UnimplementedError();

  @override
  Future<Result<Solve>> updatePenalty(String id, Penalty penalty) =>
      throw UnimplementedError();
}

void main() {
  TimerBloc build(LastEventStore? store) => TimerBloc(
        repository: _StubSolveRepository(),
        generateScramble: GenerateScramble(random: Random(0)),
        analytics: const NoopAnalytics(),
        lastEventStore: store,
      );

  test('hydrates the last-selected event on start', () async {
    final TimerBloc bloc = build(_FakeLastEventStore('4x4'));
    bloc.add(const TimerStarted());
    await bloc.stream.firstWhere((TimerState s) => s.event == '4x4');
    expect(bloc.state.event, '4x4');
    // The picker's Recent group is seeded with the restored event.
    expect(bloc.state.recentEvents, <String>['4x4']);
    await bloc.close();
  });

  test('a stale / unknown stored event falls back to 3x3', () async {
    final TimerBloc bloc = build(_FakeLastEventStore('not-a-real-event'));
    bloc.add(const TimerStarted());
    await bloc.stream.first;
    expect(bloc.state.event, '3x3');
    await bloc.close();
  });

  test('with no store the timer opens on 3x3', () async {
    final TimerBloc bloc = build(null);
    bloc.add(const TimerStarted());
    await bloc.stream.first;
    expect(bloc.state.event, '3x3');
    await bloc.close();
  });

  test('changing the event writes it back to the store', () async {
    final _FakeLastEventStore store = _FakeLastEventStore();
    final TimerBloc bloc = build(store);
    bloc.add(const TimerStarted());
    await bloc.stream.first;

    bloc.add(const TimerEventChanged('6x6'));
    await bloc.stream.firstWhere((TimerState s) => s.event == '6x6');
    expect(store.value, '6x6');
    await bloc.close();
  });
}
