import 'package:bloc_test/bloc_test.dart';
import 'package:cubeclash/core/di/injection.dart';
import 'package:cubeclash/features/profile/domain/repositories/profile_repository.dart';
import 'package:cubeclash/features/profile/presentation/cubit/settings_cubit.dart';
import 'package:cubeclash/core/router/immersive_controller.dart';
import 'package:cubeclash/features/timer/domain/entities/penalty.dart';
import 'package:cubeclash/features/timer/domain/entities/scramble.dart';
import 'package:cubeclash/features/timer/domain/entities/solve.dart';
import 'package:cubeclash/features/timer/presentation/bloc/timer_bloc.dart';
import 'package:cubeclash/features/timer/presentation/pages/timer_page.dart';
import 'package:cubeclash/features/timer/presentation/widgets/penalty_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';
import '../../support/in_memory_settings_repository.dart';

class _MockTimerBloc extends MockBloc<TimerEvent, TimerState>
    implements TimerBloc {}

/// Renders the timer view against a fixed state, bypassing the real bloc — the
/// state machine is covered exhaustively in `timer_bloc_test.dart`, so these
/// tests only assert what each state *looks like*.
void main() {
  setUpAll(initTestFonts);

  late _MockTimerBloc bloc;

  setUp(() async {
    await configureDependencies();
    // shared_preferences has no platform channel under `flutter test`.
    sl
      ..unregister<SettingsRepository>()
      ..registerSingleton<SettingsRepository>(InMemorySettingsRepository());
    bloc = _MockTimerBloc();
    // TimerPage resolves its bloc from the locator.
    sl.unregister<TimerBloc>();
    sl.registerFactory<TimerBloc>(() => bloc);
  });

  tearDown(resetDependencies);

  Future<void> pumpWithState(
    WidgetTester tester,
    TimerState state, {
    Brightness brightness = Brightness.light,
  }) async {
    whenListen(bloc, const Stream<TimerState>.empty(), initialState: state);
    await tester.pumpWidget(
      harnessPage(withAppScope(const TimerPage()), brightness: brightness),
    );
    await tester.pump();
  }

  final Scramble scramble = Scramble.parse(
    "R U R' U' F2 D B L2 F R' D2 U B2 L F' R2 D' L B U2",
    ScrambleNotation.faceTurns,
  );

  group('idle', () {
    testWidgets('shows scramble, prompt and empty-session copy',
        (WidgetTester tester) async {
      await pumpWithState(
        tester,
        TimerState(scramble: scramble),
      );

      // Figma `Timer Home`: scramble-source segments, the scramble itself,
      // the source caption and a New pill — no `SCRAMBLE` eyebrow.
      expect(find.text('Random'), findsOneWidget);
      expect(find.text('WCA comps'), findsOneWidget);
      expect(find.text('Last used'), findsOneWidget);
      expect(find.text(scramble.text), findsOneWidget);
      expect(find.text('Random scramble'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);

      expect(find.text('Hold to start'), findsOneWidget);
      expect(find.text('0.00'), findsOneWidget);

      // Session stat cards, empty until there are solves.
      expect(find.text('best'), findsOneWidget);
      expect(find.text('ao5'), findsOneWidget);
      expect(find.text('ao12'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(3));
    });

    testWidgets('penalty controls are absent before any solve',
        (WidgetTester tester) async {
      await pumpWithState(tester, TimerState(scramble: scramble));

      // The frame shows no penalty row at idle — there is nothing to penalise,
      // so it isn't rendered at all rather than rendered and dimmed.
      expect(find.byType(PenaltyControls), findsNothing);
    });
  });

  group('inspecting', () {
    testWidgets('counts down and hides the scramble card',
        (WidgetTester tester) async {
      await pumpWithState(
        tester,
        TimerState(
          status: TimerStatus.inspecting,
          scramble: scramble,
          inspectionElapsed: const Duration(seconds: 3),
        ),
      );

      // 15 - 3 = 12 seconds left.
      expect(find.text('12'), findsOneWidget);
      expect(find.text('SCRAMBLE'), findsNothing);
    });

    testWidgets('shows +2 once past 15 s', (WidgetTester tester) async {
      await pumpWithState(
        tester,
        const TimerState(
          status: TimerStatus.inspecting,
          inspectionElapsed: Duration(seconds: 16),
        ),
      );
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('shows DNF once past 17 s', (WidgetTester tester) async {
      await pumpWithState(
        tester,
        const TimerState(
          status: TimerStatus.inspecting,
          inspectionElapsed: Duration(seconds: 18),
        ),
      );
      expect(find.text('DNF'), findsOneWidget);
    });
  });

  group('running', () {
    testWidgets('is bare: numerals only, no chrome',
        (WidgetTester tester) async {
      await pumpWithState(
        tester,
        TimerState(
          status: TimerStatus.running,
          scramble: scramble,
          elapsed: const Duration(milliseconds: 8420),
        ),
      );

      expect(find.text('8.42'), findsOneWidget);
      expect(find.text('SCRAMBLE'), findsNothing);
      expect(find.text(scramble.text), findsNothing);
      expect(find.text('History'), findsNothing);
    });

    testWidgets('flags the shell to hide its nav bar',
        (WidgetTester tester) async {
      await pumpWithState(
        tester,
        const TimerState(
          status: TimerStatus.running,
          elapsed: Duration(milliseconds: 8420),
        ),
      );

      expect(sl<ImmersiveController>().value, isTrue);
    });
  });

  group('stopped', () {
    testWidgets('shows the time with its penalty and live controls',
        (WidgetTester tester) async {
      await pumpWithState(
        tester,
        TimerState(
          status: TimerStatus.stopped,
          scramble: scramble,
          elapsed: const Duration(milliseconds: 12340),
          lastSolve: Solve(
            id: 'c1',
            event: '3x3',
            scramble: scramble.text,
            timeMs: 12340,
            solvedAt: DateTime(2026, 7, 19),
            penalty: Penalty.plus2,
          ),
        ),
      );

      // Display shows the penalised time.
      expect(find.text('14.34+'), findsOneWidget);
      expect(find.text('Tap to reset'), findsOneWidget);

      expect(find.byType(PenaltyControls), findsOneWidget);
    });
  });

  group('session stats', () {
    testWidgets('shows best, ao5 and ao12 for the session',
        (WidgetTester tester) async {
      final List<Solve> solves = <Solve>[
        for (int i = 0; i < 5; i++)
          Solve(
            id: 's$i',
            event: '3x3',
            scramble: scramble.text,
            timeMs: 10000 + i * 1000,
            solvedAt: DateTime(2026, 7, 19, 10, i),
          ),
      ];

      await pumpWithState(
        tester,
        TimerState(scramble: scramble, sessionSolves: solves),
      );

      // best = the fastest of 10…14.
      expect(find.text('10.00'), findsOneWidget);
      // ao5 trims 10.00 and 14.00, means 11/12/13.
      expect(find.text('12.00'), findsOneWidget);
      // ao12 needs twelve solves — until then it reads as "not yet", not zero.
      expect(find.text('—'), findsOneWidget);
    });
  });
}

/// Wraps [page] with the app-wide providers that live above `MaterialApp` in
/// the real app — currently [SettingsCubit], which owns the theme and the
/// timer's preferences. Screens that read them need this in tests too.
Widget withAppScope(Widget page) => BlocProvider<SettingsCubit>.value(
      value: sl<SettingsCubit>(),
      child: page,
    );
