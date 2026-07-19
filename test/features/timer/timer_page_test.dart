import 'package:bloc_test/bloc_test.dart';
import 'package:cubeclash/core/di/injection.dart';
import 'package:cubeclash/features/profile/domain/repositories/profile_repository.dart';
import 'package:cubeclash/features/profile/presentation/cubit/settings_cubit.dart';
import 'package:cubeclash/core/router/immersive_controller.dart';
import 'package:cubeclash/features/timer/domain/entities/penalty.dart';
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

  const String scramble = "R U R' U' F2 D B L2 F R' D2 U B2 L F' R2 D' L B U2";

  /// Whether the penalty row is currently accepting taps. Scoped to
  /// [PenaltyControls] — the framework wraps plenty of its own IgnorePointers
  /// around a page, so an unscoped finder matches several.
  bool penaltyControlsDisabled(WidgetTester tester) => tester
      .widget<IgnorePointer>(
        find
            .descendant(
              of: find.byType(PenaltyControls),
              matching: find.byType(IgnorePointer),
            )
            .first,
      )
      .ignoring;

  group('idle', () {
    testWidgets('shows scramble, prompt and empty-session copy',
        (WidgetTester tester) async {
      await pumpWithState(
        tester,
        const TimerState(scramble: scramble),
      );

      expect(find.text('SCRAMBLE'), findsOneWidget);
      expect(find.text(scramble), findsOneWidget);
      expect(find.text('Hold to start'), findsOneWidget);
      expect(find.text('0.00'), findsOneWidget);
      expect(
        find.text('Your session starts with your first solve.'),
        findsOneWidget,
      );
    });

    testWidgets('penalty controls are inert before any solve',
        (WidgetTester tester) async {
      await pumpWithState(tester, const TimerState(scramble: scramble));

      expect(penaltyControlsDisabled(tester), isTrue);
    });
  });

  group('inspecting', () {
    testWidgets('counts down and hides the scramble card',
        (WidgetTester tester) async {
      await pumpWithState(
        tester,
        const TimerState(
          status: TimerStatus.inspecting,
          scramble: scramble,
          inspectionElapsed: Duration(seconds: 3),
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
        const TimerState(
          status: TimerStatus.running,
          scramble: scramble,
          elapsed: Duration(milliseconds: 8420),
        ),
      );

      expect(find.text('8.42'), findsOneWidget);
      expect(find.text('SCRAMBLE'), findsNothing);
      expect(find.text(scramble), findsNothing);
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
            scramble: scramble,
            timeMs: 12340,
            solvedAt: DateTime(2026, 7, 19),
            penalty: Penalty.plus2,
          ),
        ),
      );

      // Display shows the penalised time.
      expect(find.text('14.34+'), findsOneWidget);
      expect(find.text('Tap to reset'), findsOneWidget);

      expect(penaltyControlsDisabled(tester), isFalse);
    });
  });

  group('session strip', () {
    testWidgets('lists recent solves with running averages',
        (WidgetTester tester) async {
      final List<Solve> solves = <Solve>[
        for (int i = 0; i < 5; i++)
          Solve(
            id: 's$i',
            event: '3x3',
            scramble: scramble,
            timeMs: 10000 + i * 1000,
            solvedAt: DateTime(2026, 7, 19, 10, i),
          ),
      ];

      await pumpWithState(
        tester,
        TimerState(scramble: scramble, sessionSolves: solves),
      );

      expect(find.text('Ao5'), findsOneWidget);
      // Each of the five solves gets a pill, newest first.
      expect(find.text('14.00'), findsOneWidget);
      expect(find.text('10.00'), findsOneWidget);
      // Ao5 trims 10.00 and 14.00 and means 11/12/13 → 12.00, which therefore
      // appears twice: once as a solve pill, once as the average.
      expect(find.text('12.00'), findsNWidgets(2));
      // Ao12 needs 12 solves — until then it reads as "not yet", not zero.
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
