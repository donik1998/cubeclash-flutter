import 'dart:async';
import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:cubeclash/core/analytics/analytics_service.dart';
import 'package:cubeclash/core/error/failures.dart';
import 'package:cubeclash/core/error/result.dart';
import 'package:cubeclash/core/network/page.dart';
import 'package:cubeclash/features/timer/domain/entities/penalty.dart';
import 'package:cubeclash/features/timer/domain/entities/solve.dart';
import 'package:cubeclash/features/timer/domain/entities/timer_preferences.dart';
import 'package:cubeclash/features/timer/domain/repositories/solve_repository.dart';
import 'package:cubeclash/features/timer/domain/usecases/generate_scramble.dart';
import 'package:cubeclash/features/timer/presentation/bloc/timer_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_ticker.dart';

class _MockSolveRepository extends Mock implements SolveRepository {}

/// Channel indices in creation order. The bloc opens one ticker channel per
/// concern; tests address them explicitly so a hold tick can't be mistaken for
/// a solve tick.
const int _firstChannel = 0;

void main() {
  late _MockSolveRepository repository;
  late FakeTicker ticker;
  late GenerateScramble generateScramble;

  const TimerPreferences holdWithInspection = TimerPreferences();
  const TimerPreferences holdNoInspection =
      TimerPreferences(inspectionEnabled: false);
  const TimerPreferences tapNoInspection =
      TimerPreferences(style: TimerStyle.tap, inspectionEnabled: false);

  Solve solveOf({
    String id = 'c1',
    int timeMs = 12340,
    Penalty penalty = Penalty.none,
  }) =>
      Solve(
        id: id,
        event: '3x3',
        scramble: 'R U R\'',
        timeMs: timeMs,
        solvedAt: DateTime(2026, 7, 19),
        penalty: penalty,
      );

  setUpAll(() {
    registerFallbackValue(Penalty.none);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    repository = _MockSolveRepository();
    ticker = FakeTicker();
    generateScramble = GenerateScramble(random: Random(1));

    when(() => repository.watchSession())
        .thenAnswer((_) => const Stream<List<Solve>>.empty());
    // Echo the created solve back, as a real `POST /solves` does. Returning a
    // canned Solve would mask exactly the bugs these tests exist to catch —
    // the penalty and scramble the bloc actually submitted.
    when(
      () => repository.addSolve(
        event: any(named: 'event'),
        scramble: any(named: 'scramble'),
        timeMs: any(named: 'timeMs'),
        penalty: any(named: 'penalty'),
        solvedAt: any(named: 'solvedAt'),
        clientId: any(named: 'clientId'),
      ),
    ).thenAnswer(
      (Invocation call) async => Ok<Solve>(
        Solve(
          id: call.namedArguments[#clientId] as String,
          event: call.namedArguments[#event] as String,
          scramble: call.namedArguments[#scramble] as String,
          timeMs: call.namedArguments[#timeMs] as int,
          solvedAt: call.namedArguments[#solvedAt] as DateTime,
          penalty: call.namedArguments[#penalty] as Penalty,
        ),
      ),
    );
    when(() => repository.updatePenalty(any(), any()))
        .thenAnswer((_) async => Ok<Solve>(solveOf()));
    when(() => repository.clearSession())
        .thenAnswer((_) async => const Ok<void>(null));
    when(() => repository.getHistory(
          event: any(named: 'event'),
          cursor: any(named: 'cursor'),
        )).thenAnswer(
      (_) async => const Ok<Page<Solve>>(Page<Solve>(items: <Solve>[])),
    );
  });

  tearDown(() => ticker.dispose());

  TimerBloc build({TimerPreferences preferences = holdWithInspection}) {
    final TimerBloc bloc = TimerBloc(
      repository: repository,
      generateScramble: generateScramble,
      analytics: const NoopAnalytics(),
      ticker: ticker,
      idFactory: () => 'c1',
    );
    bloc.add(TimerPreferencesChanged(preferences));
    return bloc;
  }

  group('startup', () {
    blocTest<TimerBloc, TimerState>(
      'proposes a scramble on start',
      build: build,
      act: (TimerBloc bloc) => bloc.add(const TimerStarted()),
      verify: (TimerBloc bloc) {
        expect(bloc.state.scramble, isNotEmpty);
        expect(bloc.state.status, TimerStatus.idle);
        verify(() => repository.watchSession()).called(1);
      },
    );

    blocTest<TimerBloc, TimerState>(
      'a new scramble can be requested while idle',
      build: build,
      act: (TimerBloc bloc) async {
        bloc.add(const TimerStarted());
        await Future<void>.delayed(Duration.zero);
        final String first = bloc.state.scramble;
        bloc.add(const TimerScrambleRequested());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.scramble, isNot(first));
      },
    );
  });

  group('hold-to-start, inspection off', () {
    blocTest<TimerBloc, TimerState>(
      'arms only once the hold threshold is met, then starts on release',
      build: () => build(preferences: holdNoInspection),
      act: (TimerBloc bloc) async {
        bloc.add(const TimerStarted());
        await Future<void>.delayed(Duration.zero);

        bloc.add(const TimerPressedDown());
        await Future<void>.delayed(Duration.zero);

        // Halfway through the hold — armed affordance, but not armed.
        ticker.emitTo(_firstChannel, const Duration(milliseconds: 275));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, TimerStatus.idle);
        expect(bloc.state.holdProgress, closeTo(0.5, 0.01));

        // Threshold met.
        ticker.emitTo(_firstChannel, TimerPreferences.holdThreshold);
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, TimerStatus.ready);

        bloc.add(const TimerPressedUp());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, TimerStatus.running);
      },
    );

    blocTest<TimerBloc, TimerState>(
      'releasing before the threshold is a false start, not a solve',
      build: () => build(preferences: holdNoInspection),
      act: (TimerBloc bloc) async {
        bloc.add(const TimerStarted());
        await Future<void>.delayed(Duration.zero);

        bloc.add(const TimerPressedDown());
        await Future<void>.delayed(Duration.zero);
        ticker.emitTo(_firstChannel, const Duration(milliseconds: 100));
        await Future<void>.delayed(Duration.zero);

        bloc.add(const TimerPressedUp());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (TimerBloc bloc) {
        expect(bloc.state.status, TimerStatus.idle);
        expect(bloc.state.holdProgress, 0);
      },
    );
  });

  group('tap-to-start', () {
    blocTest<TimerBloc, TimerState>(
      'a tap starts and a press stops, with no arming step',
      build: () => build(preferences: tapNoInspection),
      act: (TimerBloc bloc) async {
        bloc.add(const TimerStarted());
        await Future<void>.delayed(Duration.zero);

        bloc.add(const TimerPressedUp());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, TimerStatus.running);

        ticker.emit(const Duration(milliseconds: 9870));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.elapsed, const Duration(milliseconds: 9870));

        bloc.add(const TimerPressedDown());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(bloc.state.status, TimerStatus.stopped);
      },
      verify: (TimerBloc bloc) {
        verify(
          () => repository.addSolve(
            event: '3x3',
            scramble: any(named: 'scramble'),
            timeMs: 9870,
            penalty: Penalty.none,
            solvedAt: any(named: 'solvedAt'),
            clientId: 'c1',
          ),
        ).called(1);
      },
    );

    blocTest<TimerBloc, TimerState>(
      'the press that stops a solve does not arm the next one',
      build: () => build(preferences: tapNoInspection),
      act: (TimerBloc bloc) async {
        bloc.add(const TimerStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TimerPressedUp());
        await Future<void>.delayed(Duration.zero);

        bloc.add(const TimerPressedDown());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        // The release of that same press must be swallowed.
        bloc.add(const TimerPressedUp());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (TimerBloc bloc) =>
          expect(bloc.state.status, TimerStatus.stopped),
    );

    blocTest<TimerBloc, TimerState>(
      'acknowledging a finished solve returns to idle without restarting',
      build: () => build(preferences: tapNoInspection),
      act: (TimerBloc bloc) async {
        bloc.add(const TimerStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TimerPressedUp());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TimerPressedDown());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const TimerPressedUp());
        await Future<void>.delayed(Duration.zero);

        // A fresh press from `stopped` resets.
        bloc.add(const TimerPressedDown());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.status, TimerStatus.idle);

        bloc.add(const TimerPressedUp());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (TimerBloc bloc) => expect(
        bloc.state.status,
        TimerStatus.idle,
        reason: 'the release that ended the reset press must be swallowed',
      ),
    );
  });

  group('inspection', () {
    /// Drives the bloc to `running` after inspecting for [inspectionElapsed],
    /// then stops the solve at [solveMs].
    Future<void> solveAfterInspecting(
      TimerBloc bloc, {
      required Duration inspectionElapsed,
      int solveMs = 12340,
    }) async {
      bloc.add(const TimerStarted());
      await Future<void>.delayed(Duration.zero);

      // Tap to begin inspection. Channel 0 is the inspection ticker.
      bloc.add(const TimerPressedUp());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, TimerStatus.inspecting);

      ticker.emitTo(_firstChannel, inspectionElapsed);
      await Future<void>.delayed(Duration.zero);

      // Hold to arm — channel 1.
      bloc.add(const TimerPressedDown());
      await Future<void>.delayed(Duration.zero);
      ticker.emitTo(1, TimerPreferences.holdThreshold);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, TimerStatus.ready);

      bloc.add(const TimerPressedUp());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, TimerStatus.running);

      // Solve ticker — channel 2.
      ticker.emitTo(2, Duration(milliseconds: solveMs));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const TimerPressedDown());
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    blocTest<TimerBloc, TimerState>(
      'a tap from idle begins inspection rather than a solve',
      build: build,
      act: (TimerBloc bloc) async {
        bloc.add(const TimerStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TimerPressedUp());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (TimerBloc bloc) =>
          expect(bloc.state.status, TimerStatus.inspecting),
    );

    blocTest<TimerBloc, TimerState>(
      'finishing inspection inside 15 s carries no penalty',
      build: build,
      act: (TimerBloc bloc) => solveAfterInspecting(
        bloc,
        inspectionElapsed: const Duration(seconds: 12),
      ),
      verify: (TimerBloc bloc) {
        expect(bloc.state.lastSolve?.penalty, Penalty.none);
        verify(
          () => repository.addSolve(
            event: any(named: 'event'),
            scramble: any(named: 'scramble'),
            timeMs: any(named: 'timeMs'),
            penalty: Penalty.none,
            solvedAt: any(named: 'solvedAt'),
            clientId: any(named: 'clientId'),
          ),
        ).called(1);
      },
    );

    blocTest<TimerBloc, TimerState>(
      'exactly 15.000 s is still clean',
      build: build,
      act: (TimerBloc bloc) => solveAfterInspecting(
        bloc,
        inspectionElapsed: const Duration(seconds: 15),
      ),
      verify: (TimerBloc bloc) =>
          expect(bloc.state.lastSolve?.penalty, Penalty.none),
    );

    blocTest<TimerBloc, TimerState>(
      'between 15 s and 17 s is a +2',
      build: build,
      act: (TimerBloc bloc) => solveAfterInspecting(
        bloc,
        inspectionElapsed: const Duration(seconds: 16),
      ),
      verify: (TimerBloc bloc) {
        expect(bloc.state.lastSolve?.penalty, Penalty.plus2);
        // The +2 applies to the recorded time, it does not alter it.
        expect(bloc.state.lastSolve?.timeMs, 12340);
        expect(bloc.state.lastSolve?.effectiveTimeMs, 14340);
      },
    );

    blocTest<TimerBloc, TimerState>(
      'past 17 s is a DNF',
      build: build,
      act: (TimerBloc bloc) => solveAfterInspecting(
        bloc,
        inspectionElapsed: const Duration(seconds: 17, milliseconds: 500),
      ),
      verify: (TimerBloc bloc) {
        expect(bloc.state.lastSolve?.penalty, Penalty.dnf);
        expect(bloc.state.lastSolve?.effectiveTimeMs, isNull);
      },
    );

    blocTest<TimerBloc, TimerState>(
      'inspection penalties are skipped entirely when inspection is off',
      build: () => build(preferences: tapNoInspection),
      act: (TimerBloc bloc) async {
        bloc.add(const TimerStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TimerPressedUp());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TimerPressedDown());
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
      verify: (TimerBloc bloc) =>
          expect(bloc.state.lastSolve?.penalty, Penalty.none),
    );
  });

  group('after a solve', () {
    Future<void> completeSolve(TimerBloc bloc) async {
      bloc.add(const TimerStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const TimerPressedUp());
      await Future<void>.delayed(Duration.zero);
      ticker.emit(const Duration(milliseconds: 12340));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const TimerPressedDown());
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    blocTest<TimerBloc, TimerState>(
      'proposes a fresh scramble for the next solve',
      build: () => build(preferences: tapNoInspection),
      act: (TimerBloc bloc) async {
        bloc.add(const TimerStarted());
        await Future<void>.delayed(Duration.zero);
        final String scrambleSolved = bloc.state.scramble;

        bloc.add(const TimerPressedUp());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TimerPressedDown());
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(bloc.state.scramble, isNot(scrambleSolved));
        expect(
          bloc.state.lastSolve?.scramble,
          scrambleSolved,
          reason: 'the solve keeps the scramble it was actually solved on',
        );
      },
    );

    blocTest<TimerBloc, TimerState>(
      'applies a penalty optimistically',
      build: () => build(preferences: tapNoInspection),
      act: (TimerBloc bloc) async {
        await completeSolve(bloc);
        when(() => repository.updatePenalty(any(), any())).thenAnswer(
          (_) async => Ok<Solve>(solveOf(penalty: Penalty.plus2)),
        );
        bloc.add(const TimerPenaltyChanged(Penalty.plus2));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
      verify: (TimerBloc bloc) {
        expect(bloc.state.lastSolve?.penalty, Penalty.plus2);
        verify(() => repository.updatePenalty('c1', Penalty.plus2)).called(1);
      },
    );

    blocTest<TimerBloc, TimerState>(
      'rolls the penalty back if the write fails',
      build: () => build(preferences: tapNoInspection),
      act: (TimerBloc bloc) async {
        await completeSolve(bloc);
        when(() => repository.updatePenalty(any(), any())).thenAnswer(
          (_) async => const Err<Solve>(NetworkFailure('offline')),
        );
        bloc.add(const TimerPenaltyChanged(Penalty.dnf));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
      verify: (TimerBloc bloc) {
        expect(
          bloc.state.lastSolve?.penalty,
          Penalty.none,
          reason: 'the UI must not claim a penalty the server never accepted',
        );
        expect(bloc.state.failure, isA<NetworkFailure>());
      },
    );

    blocTest<TimerBloc, TimerState>(
      'a failed save surfaces the error but keeps the time on screen',
      build: () => build(preferences: tapNoInspection),
      setUp: () {
        when(
          () => repository.addSolve(
            event: any(named: 'event'),
            scramble: any(named: 'scramble'),
            timeMs: any(named: 'timeMs'),
            penalty: any(named: 'penalty'),
            solvedAt: any(named: 'solvedAt'),
            clientId: any(named: 'clientId'),
          ),
        ).thenAnswer((_) async => const Err<Solve>(NetworkFailure('offline')));
      },
      act: completeSolve,
      verify: (TimerBloc bloc) {
        expect(bloc.state.status, TimerStatus.stopped);
        expect(bloc.state.elapsed, const Duration(milliseconds: 12340));
        expect(bloc.state.lastSolve?.timeMs, 12340);
        expect(bloc.state.failure, isA<NetworkFailure>());
        expect(bloc.state.isSaving, isFalse);
      },
    );

    blocTest<TimerBloc, TimerState>(
      'the failure can be dismissed',
      build: () => build(preferences: tapNoInspection),
      setUp: () {
        when(
          () => repository.addSolve(
            event: any(named: 'event'),
            scramble: any(named: 'scramble'),
            timeMs: any(named: 'timeMs'),
            penalty: any(named: 'penalty'),
            solvedAt: any(named: 'solvedAt'),
            clientId: any(named: 'clientId'),
          ),
        ).thenAnswer((_) async => const Err<Solve>(NetworkFailure('offline')));
      },
      act: (TimerBloc bloc) async {
        await completeSolve(bloc);
        bloc.add(const TimerFailureDismissed());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (TimerBloc bloc) => expect(bloc.state.failure, isNull),
    );
  });

  group('session', () {
    blocTest<TimerBloc, TimerState>(
      'session solves flow in from the repository stream',
      build: build,
      setUp: () {
        when(() => repository.watchSession()).thenAnswer(
          (_) => Stream<List<Solve>>.value(<Solve>[
            solveOf(id: 'a', timeMs: 10000),
            solveOf(id: 'b', timeMs: 11000),
            solveOf(id: 'c', timeMs: 12000),
            solveOf(id: 'd', timeMs: 13000),
            solveOf(id: 'e', timeMs: 14000),
          ]),
        );
      },
      act: (TimerBloc bloc) async {
        bloc.add(const TimerStarted());
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
      verify: (TimerBloc bloc) {
        expect(bloc.state.sessionSolves, hasLength(5));
        expect(bloc.state.sessionBest, 10000);
        // ao5 trims 10000 and 14000, means the rest.
        expect(bloc.state.sessionAo5, 12000);
      },
    );

    blocTest<TimerBloc, TimerState>(
      'clearing the session resets the timer',
      build: build,
      act: (TimerBloc bloc) async {
        bloc.add(const TimerSessionCleared());
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
      verify: (TimerBloc bloc) {
        expect(bloc.state.status, TimerStatus.idle);
        expect(bloc.state.lastSolve, isNull);
        verify(() => repository.clearSession()).called(1);
      },
    );
  });

  group('guards', () {
    blocTest<TimerBloc, TimerState>(
      'the scramble cannot change mid-solve',
      build: () => build(preferences: tapNoInspection),
      act: (TimerBloc bloc) async {
        bloc.add(const TimerStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TimerPressedUp());
        await Future<void>.delayed(Duration.zero);

        final String during = bloc.state.scramble;
        bloc.add(const TimerScrambleRequested());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.scramble, during);
      },
    );

    blocTest<TimerBloc, TimerState>(
      'changing event resets the timer and re-scrambles',
      build: build,
      act: (TimerBloc bloc) async {
        bloc.add(const TimerStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TimerEventChanged('2x2'));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (TimerBloc bloc) {
        expect(bloc.state.event, '2x2');
        expect(bloc.state.status, TimerStatus.idle);
        expect(bloc.state.scramble.split(' '), hasLength(11));
      },
    );
  });
}
