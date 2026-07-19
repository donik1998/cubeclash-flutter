import 'package:bloc_test/bloc_test.dart';
import 'package:cubeclash/core/di/injection.dart';
import 'package:cubeclash/features/profile/domain/repositories/profile_repository.dart';
import 'package:cubeclash/features/profile/presentation/cubit/settings_cubit.dart';
import 'package:cubeclash/features/timer/domain/entities/penalty.dart';
import 'package:cubeclash/features/timer/domain/entities/solve.dart';
import 'package:cubeclash/features/timer/presentation/bloc/timer_bloc.dart';
import 'package:cubeclash/features/timer/presentation/pages/timer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';
import '../../support/in_memory_settings_repository.dart';

class _MockTimerBloc extends MockBloc<TimerEvent, TimerState>
    implements TimerBloc {}

/// Goldens for the hero screen in light + dark, across the states that look
/// meaningfully different.
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
    sl.unregister<TimerBloc>();
    sl.registerFactory<TimerBloc>(() => bloc);
  });

  tearDown(resetDependencies);

  const String scramble = "R U R' U' F2 D B L2 F R' D2 U B2 L F' R2 D' L B U2";
  const Size phone = Size(390, 780);

  List<Solve> sessionOf(List<int> timesMs) => <Solve>[
        for (int i = 0; i < timesMs.length; i++)
          Solve(
            id: 's$i',
            event: '3x3',
            scramble: scramble,
            timeMs: timesMs[i],
            solvedAt: DateTime(2026, 7, 19, 10, i),
          ),
      ];

  Future<void> goldenFor(
    WidgetTester tester,
    TimerState state, {
    required String name,
  }) async {
    for (final (String suffix, Brightness brightness) in <(String, Brightness)>[
      ('light', Brightness.light),
      ('dark', Brightness.dark),
    ]) {
      whenListen(bloc, const Stream<TimerState>.empty(), initialState: state);
      await tester.binding.setSurfaceSize(phone);
      await tester.pumpWidget(
        harnessPage(withAppScope(const TimerPage()),
            brightness: brightness, size: phone),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/timer_${name}_$suffix.png'),
      );
    }
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('idle with a session', (WidgetTester tester) async {
    await goldenFor(
      tester,
      TimerState(
        scramble: scramble,
        sessionSolves: sessionOf(<int>[11230, 9870, 13450, 10990, 12010]),
      ),
      name: 'idle',
    );
  });

  testWidgets('idle with an empty session', (WidgetTester tester) async {
    await goldenFor(
      tester,
      const TimerState(scramble: scramble),
      name: 'idle_empty',
    );
  });

  testWidgets('inspecting', (WidgetTester tester) async {
    await goldenFor(
      tester,
      const TimerState(
        status: TimerStatus.inspecting,
        scramble: scramble,
        inspectionElapsed: Duration(seconds: 7),
      ),
      name: 'inspecting',
    );
  });

  testWidgets('running is bare', (WidgetTester tester) async {
    await goldenFor(
      tester,
      const TimerState(
        status: TimerStatus.running,
        scramble: scramble,
        elapsed: Duration(milliseconds: 8420),
      ),
      name: 'running',
    );
  });

  testWidgets('stopped with a +2', (WidgetTester tester) async {
    await goldenFor(
      tester,
      TimerState(
        status: TimerStatus.stopped,
        scramble: scramble,
        elapsed: const Duration(milliseconds: 12340),
        sessionSolves: sessionOf(<int>[11230, 9870, 13450, 10990, 12340]),
        lastSolve: Solve(
          id: 's4',
          event: '3x3',
          scramble: scramble,
          timeMs: 12340,
          solvedAt: DateTime(2026, 7, 19, 10, 4),
          penalty: Penalty.plus2,
        ),
      ),
      name: 'stopped_plus2',
    );
  });
}

/// Wraps [page] with the app-wide providers that live above `MaterialApp` in
/// the real app — currently [SettingsCubit], which owns the theme and the
/// timer's preferences. Screens that read them need this in tests too.
Widget withAppScope(Widget page) => BlocProvider<SettingsCubit>.value(
      value: sl<SettingsCubit>(),
      child: page,
    );
