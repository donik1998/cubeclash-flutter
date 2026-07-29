import 'package:cubeclash/core/analytics/analytics_service.dart';
import 'package:cubeclash/core/error/failures.dart';
import 'package:cubeclash/core/error/result.dart';
import 'package:cubeclash/features/stats/domain/entities/leaderboard_entry.dart';
import 'package:cubeclash/features/stats/domain/entities/player_stats.dart';
import 'package:cubeclash/features/stats/domain/repositories/stats_repository.dart';
import 'package:cubeclash/features/stats/presentation/cubit/stats_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStatsRepository extends Mock implements StatsRepository {}

void main() {
  late _MockStatsRepository repository;

  LeaderboardEntry entry(int rank, {String? id}) => LeaderboardEntry(
        userId: id ?? 'u$rank',
        rank: rank,
        displayName: 'Player $rank',
        timeMs: 6000 + rank * 100,
        countryCode: 'GB',
      );

  const LeaderboardEntry me = LeaderboardEntry(
    userId: 'me',
    rank: 47,
    displayName: 'You',
    timeMs: 11200,
    isCurrentUser: true,
  );

  setUpAll(() {
    registerFallbackValue(LeaderboardMetric.single);
    registerFallbackValue(LeaderboardScope.global);
  });

  setUp(() {
    repository = _MockStatsRepository();

    when(() => repository.getStats(event: any(named: 'event'))).thenAnswer(
      (_) async => const Ok<PlayerStats>(
        PlayerStats(event: '3x3', solveCount: 120, bestSingleMs: 8420),
      ),
    );
    when(() => repository.getLeaderboard(
          event: any(named: 'event'),
          metric: any(named: 'metric'),
          scope: any(named: 'scope'),
          cursor: any(named: 'cursor'),
        )).thenAnswer(
      (_) async => Ok<Leaderboard>(
        Leaderboard(
          entries: <LeaderboardEntry>[entry(1), entry(2)],
          viewer: me,
        ),
      ),
    );
  });

  StatsCubit build() => StatsCubit(
        repository: repository,
        analytics: const NoopAnalytics(),
      );

  group('segments', () {
    test('opening Stats loads only My Stats, not the leaderboard', () async {
      final StatsCubit cubit = build();
      await cubit.start();

      verify(() => repository.getStats(event: any(named: 'event'))).called(1);
      verifyNever(() => repository.getLeaderboard(
            event: any(named: 'event'),
            metric: any(named: 'metric'),
            scope: any(named: 'scope'),
            cursor: any(named: 'cursor'),
          ));
    });

    test('switching to Leaderboards loads it lazily, once', () async {
      final StatsCubit cubit = build();
      await cubit.start();

      cubit.selectSegment(StatsSegment.leaderboards);
      await Future<void>.delayed(Duration.zero);
      cubit.selectSegment(StatsSegment.myStats);
      cubit.selectSegment(StatsSegment.leaderboards);
      await Future<void>.delayed(Duration.zero);

      verify(() => repository.getLeaderboard(
            event: any(named: 'event'),
            metric: any(named: 'metric'),
            scope: any(named: 'scope'),
            cursor: any(named: 'cursor'),
          )).called(1);
    });
  });

  group('My Stats states', () {
    test('zero solves is the empty state, not an error', () async {
      when(() => repository.getStats(event: any(named: 'event'))).thenAnswer(
        (_) async =>
            const Ok<PlayerStats>(PlayerStats(event: '3x3', solveCount: 0)),
      );

      final StatsCubit cubit = build();
      await cubit.start();

      expect(cubit.state.statsEmpty, isTrue);
      expect(cubit.state.statsTooThin, isFalse);
      expect(cubit.state.statsFailure, isNull);
    });

    test('a handful of solves is "too thin for charts", not empty', () async {
      when(() => repository.getStats(event: any(named: 'event'))).thenAnswer(
        (_) async =>
            const Ok<PlayerStats>(PlayerStats(event: '3x3', solveCount: 4)),
      );

      final StatsCubit cubit = build();
      await cubit.start();

      expect(cubit.state.statsEmpty, isFalse);
      expect(cubit.state.statsTooThin, isTrue);
    });

    test('enough solves shows the charts', () async {
      final StatsCubit cubit = build();
      await cubit.start();

      expect(cubit.state.statsEmpty, isFalse);
      expect(cubit.state.statsTooThin, isFalse);
      expect(cubit.state.stats?.hasEnoughForCharts, isTrue);
    });

    test('a failure surfaces and clears on retry', () async {
      when(() => repository.getStats(event: any(named: 'event'))).thenAnswer(
        (_) async => const Err<PlayerStats>(NetworkFailure('offline')),
      );

      final StatsCubit cubit = build();
      await cubit.start();
      expect(cubit.state.statsFailure, isA<NetworkFailure>());

      when(() => repository.getStats(event: any(named: 'event'))).thenAnswer(
        (_) async => const Ok<PlayerStats>(
          PlayerStats(event: '3x3', solveCount: 50),
        ),
      );
      await cubit.loadStats();

      expect(cubit.state.statsFailure, isNull);
      expect(cubit.state.stats?.solveCount, 50);
    });
  });

  group('leaderboard', () {
    test('pins the current user when their row is not loaded', () async {
      final StatsCubit cubit = build();
      await cubit.loadLeaderboard();

      expect(cubit.state.pinnedViewer?.userId, 'me');
    });

    test('does not pin a duplicate when their row is already visible',
        () async {
      when(() => repository.getLeaderboard(
            event: any(named: 'event'),
            metric: any(named: 'metric'),
            scope: any(named: 'scope'),
            cursor: any(named: 'cursor'),
          )).thenAnswer(
        (_) async => Ok<Leaderboard>(
          Leaderboard(
            entries: <LeaderboardEntry>[entry(1), entry(2, id: 'me')],
            viewer: me,
          ),
        ),
      );

      final StatsCubit cubit = build();
      await cubit.loadLeaderboard();

      expect(cubit.state.pinnedViewer, isNull);
    });

    test('changing scope refetches and drops the stale page', () async {
      final StatsCubit cubit = build();
      await cubit.loadLeaderboard();
      await cubit.changeScope(LeaderboardScope.friends);

      expect(cubit.state.scope, LeaderboardScope.friends);
      verify(() => repository.getLeaderboard(
            event: any(named: 'event'),
            metric: any(named: 'metric'),
            scope: LeaderboardScope.friends,
            cursor: null,
          )).called(1);
    });

    test('changing metric refetches', () async {
      final StatsCubit cubit = build();
      await cubit.loadLeaderboard();
      await cubit.changeMetric(LeaderboardMetric.ao5);

      expect(cubit.state.metric, LeaderboardMetric.ao5);
      verify(() => repository.getLeaderboard(
            event: any(named: 'event'),
            metric: LeaderboardMetric.ao5,
            scope: any(named: 'scope'),
            cursor: null,
          )).called(1);
    });

    test('changing metric to ao12 refetches with the ao12 wire value',
        () async {
      final StatsCubit cubit = build();
      await cubit.loadLeaderboard();
      await cubit.changeMetric(LeaderboardMetric.ao12);

      expect(cubit.state.metric, LeaderboardMetric.ao12);
      expect(LeaderboardMetric.ao12.wire, 'ao12');
      verify(() => repository.getLeaderboard(
            event: any(named: 'event'),
            metric: LeaderboardMetric.ao12,
            scope: any(named: 'scope'),
            cursor: null,
          )).called(1);
    });

    test('a failure surfaces as leaderboardFailure', () async {
      when(() => repository.getLeaderboard(
            event: any(named: 'event'),
            metric: any(named: 'metric'),
            scope: any(named: 'scope'),
            cursor: any(named: 'cursor'),
          )).thenAnswer(
        (_) async => const Err<Leaderboard>(NetworkFailure('offline')),
      );

      final StatsCubit cubit = build();
      await cubit.loadLeaderboard();

      expect(cubit.state.leaderboardFailure, isA<NetworkFailure>());
      expect(cubit.state.isLoadingLeaderboard, isFalse);
      expect(cubit.state.pinnedViewer, isNull);
    });

    test('the viewer is surfaced and pinned when off the loaded page',
        () async {
      final StatsCubit cubit = build();
      await cubit.loadLeaderboard();

      // Default stub returns entries [1,2] and viewer=me(rank 47), so the
      // viewer is not on the page and must be pinned.
      expect(cubit.state.leaderboard?.viewer?.userId, 'me');
      expect(cubit.state.pinnedViewer?.userId, 'me');
      expect(cubit.state.pinnedViewer?.isCurrentUser, isTrue);
    });

    test('re-selecting the current scope does not refetch', () async {
      final StatsCubit cubit = build();
      await cubit.loadLeaderboard();
      await cubit.changeScope(LeaderboardScope.global);

      verify(() => repository.getLeaderboard(
            event: any(named: 'event'),
            metric: any(named: 'metric'),
            scope: any(named: 'scope'),
            cursor: any(named: 'cursor'),
          )).called(1);
    });

    test('loadMore appends without losing the pinned user', () async {
      when(() => repository.getLeaderboard(
            event: any(named: 'event'),
            metric: any(named: 'metric'),
            scope: any(named: 'scope'),
            cursor: null,
          )).thenAnswer(
        (_) async => Ok<Leaderboard>(
          Leaderboard(
            entries: <LeaderboardEntry>[entry(1)],
            viewer: me,
            nextCursor: '1',
          ),
        ),
      );
      when(() => repository.getLeaderboard(
            event: any(named: 'event'),
            metric: any(named: 'metric'),
            scope: any(named: 'scope'),
            cursor: '1',
          )).thenAnswer(
        (_) async => Ok<Leaderboard>(
          Leaderboard(entries: <LeaderboardEntry>[entry(2)]),
        ),
      );

      final StatsCubit cubit = build();
      await cubit.loadLeaderboard();
      await cubit.loadMoreLeaderboard();

      expect(cubit.state.leaderboard?.entries, hasLength(2));
      expect(cubit.state.leaderboard?.hasMore, isFalse);
      expect(
        cubit.state.pinnedViewer?.userId,
        'me',
        reason: 'a page that omits viewer must not drop it',
      );
    });

    test('loadMore is a no-op with no cursor', () async {
      final StatsCubit cubit = build();
      await cubit.loadLeaderboard();
      await cubit.loadMoreLeaderboard();

      verify(() => repository.getLeaderboard(
            event: any(named: 'event'),
            metric: any(named: 'metric'),
            scope: any(named: 'scope'),
            cursor: any(named: 'cursor'),
          )).called(1);
    });

    test('an empty board is the empty state', () async {
      when(() => repository.getLeaderboard(
            event: any(named: 'event'),
            metric: any(named: 'metric'),
            scope: any(named: 'scope'),
            cursor: any(named: 'cursor'),
          )).thenAnswer(
        (_) async =>
            const Ok<Leaderboard>(Leaderboard(entries: <LeaderboardEntry>[])),
      );

      final StatsCubit cubit = build();
      await cubit.loadLeaderboard();

      expect(cubit.state.leaderboardEmpty, isTrue);
      expect(cubit.state.leaderboardFailure, isNull);
    });
  });
}
