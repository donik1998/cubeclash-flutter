import 'package:bloc_test/bloc_test.dart';
import 'package:cubeclash/core/di/injection.dart';
import 'package:cubeclash/features/stats/domain/entities/leaderboard_entry.dart';
import 'package:cubeclash/features/stats/domain/entities/player_stats.dart';
import 'package:cubeclash/features/stats/presentation/cubit/stats_cubit.dart';
import 'package:cubeclash/features/stats/presentation/pages/stats_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/harness.dart';

class _MockStatsCubit extends MockCubit<StatsState> implements StatsCubit {}

void main() {
  setUpAll(initTestFonts);

  late _MockStatsCubit cubit;

  setUp(() async {
    await configureDependencies();
    cubit = _MockStatsCubit();

    // Mocktail returns null for unstubbed calls, which blows up on a declared
    // `Future<void>` return. Stub everything the page invokes on build.
    when(cubit.start).thenAnswer((_) async {});
    when(cubit.loadStats).thenAnswer((_) async {});
    when(cubit.loadLeaderboard).thenAnswer((_) async {});
    when(cubit.loadMoreLeaderboard).thenAnswer((_) async {});
    when(() => cubit.close()).thenAnswer((_) async {});

    sl.unregister<StatsCubit>();
    sl.registerFactory<StatsCubit>(() => cubit);
  });

  tearDown(resetDependencies);

  const Size phone = Size(390, 780);

  final PlayerStats richStats = PlayerStats(
    event: '3x3',
    solveCount: 142,
    bestSingleMs: 8420,
    bestAo5Ms: 10960,
    bestAo12Ms: 11540,
    bestAo100Ms: 12310,
    progress: <StatsPoint>[
      for (int i = 0; i < 14; i++)
        StatsPoint(
          day: DateTime(2026, 7, 6).add(Duration(days: i)),
          // A believable improving trend with day-to-day noise.
          averageMs: 15200 - i * 220 + (i.isEven ? 340 : -180),
          bestMs: 12800 - i * 200 + (i % 3 == 0 ? 260 : -140),
          solveCount: 6 + i % 4,
        ),
    ],
    distribution: const <HistogramBucket>[
      HistogramBucket(fromMs: 8000, toMs: 9000, count: 1),
      HistogramBucket(fromMs: 9000, toMs: 10000, count: 4),
      HistogramBucket(fromMs: 10000, toMs: 11000, count: 11),
      HistogramBucket(fromMs: 11000, toMs: 12000, count: 23),
      HistogramBucket(fromMs: 12000, toMs: 13000, count: 31),
      HistogramBucket(fromMs: 13000, toMs: 14000, count: 26),
      HistogramBucket(fromMs: 14000, toMs: 15000, count: 17),
      HistogramBucket(fromMs: 15000, toMs: 16000, count: 9),
      HistogramBucket(fromMs: 16000, toMs: 17000, count: 5),
      HistogramBucket(fromMs: 17000, toMs: 18000, count: 2),
    ],
  );

  const Leaderboard board = Leaderboard(
    entries: <LeaderboardEntry>[
      LeaderboardEntry(
        userId: 'u1',
        rank: 1,
        displayName: 'Yuki Tanaka',
        timeMs: 5980,
        countryCode: 'JP',
      ),
      LeaderboardEntry(
        userId: 'u2',
        rank: 2,
        displayName: 'Ana Silva',
        timeMs: 6310,
        countryCode: 'BR',
      ),
      LeaderboardEntry(
        userId: 'u3',
        rank: 3,
        displayName: 'Tomas Novak',
        timeMs: 6440,
        countryCode: 'CZ',
      ),
      LeaderboardEntry(
        userId: 'u4',
        rank: 4,
        displayName: 'Priya Nair',
        timeMs: 6720,
        countryCode: 'IN',
      ),
      LeaderboardEntry(
        userId: 'u5',
        rank: 5,
        displayName: 'Lukas Meyer',
        timeMs: 6890,
        countryCode: 'DE',
      ),
    ],
    viewer: LeaderboardEntry(
      userId: 'me',
      rank: 47,
      displayName: 'You',
      timeMs: 11200,
      countryCode: 'GB',
      isCurrentUser: true,
    ),
  );

  Future<void> goldenFor(
    WidgetTester tester,
    StatsState state, {
    required String name,
  }) async {
    for (final (String suffix, Brightness brightness) in <(String, Brightness)>[
      ('light', Brightness.light),
      ('dark', Brightness.dark),
    ]) {
      whenListen(cubit, const Stream<StatsState>.empty(), initialState: state);
      await tester.binding.setSurfaceSize(phone);
      await tester.pumpWidget(
        harnessPage(const StatsPage(), brightness: brightness, size: phone),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/stats_${name}_$suffix.png'),
      );
    }
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('My Stats with charts', (WidgetTester tester) async {
    await goldenFor(
      tester,
      StatsState(stats: richStats, isLoadingStats: false),
      name: 'my_stats',
    );
  });

  testWidgets('My Stats with too few solves for charts',
      (WidgetTester tester) async {
    await goldenFor(
      tester,
      const StatsState(
        stats: PlayerStats(
          event: '3x3',
          solveCount: 4,
          bestSingleMs: 14320,
          bestAo5Ms: null,
        ),
        isLoadingStats: false,
      ),
      name: 'my_stats_thin',
    );
  });

  testWidgets('My Stats empty', (WidgetTester tester) async {
    await goldenFor(
      tester,
      const StatsState(
        stats: PlayerStats(event: '3x3', solveCount: 0),
        isLoadingStats: false,
      ),
      name: 'my_stats_empty',
    );
  });

  testWidgets('Leaderboard with the current user pinned',
      (WidgetTester tester) async {
    await goldenFor(
      tester,
      const StatsState(
        segment: StatsSegment.leaderboards,
        leaderboard: board,
        isLoadingLeaderboard: false,
        isLoadingStats: false,
      ),
      name: 'leaderboard',
    );
  });

  testWidgets('Leaderboard empty for friends scope',
      (WidgetTester tester) async {
    await goldenFor(
      tester,
      const StatsState(
        segment: StatsSegment.leaderboards,
        scope: LeaderboardScope.friends,
        leaderboard: Leaderboard(entries: <LeaderboardEntry>[]),
        isLoadingLeaderboard: false,
        isLoadingStats: false,
      ),
      name: 'leaderboard_empty',
    );
  });
}
