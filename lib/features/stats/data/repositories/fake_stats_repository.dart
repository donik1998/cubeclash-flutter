import 'dart:math';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/player_stats.dart';
import '../../domain/repositories/stats_repository.dart';

/// Seeded in-memory [StatsRepository] — see [FakeSolveRepository] for why the
/// fakes exist at all.
///
/// The leaderboard is ten plausible cubers with real country codes and times
/// spread across a believable range, plus the signed-in user parked outside
/// the podium so the "pin my row" behaviour is actually exercised in the demo.
class FakeStatsRepository implements StatsRepository {
  FakeStatsRepository({Random? random, DateTime? now})
      : _random = random ?? Random(11),
        _now = now ?? DateTime.now();

  final Random _random;
  final DateTime _now;

  static const Duration _latency = Duration(milliseconds: 260);
  static const String currentUserId = 'me';
  static const int _pageSize = 20;

  /// The signed-in user's rank. Deliberately well down the list.
  static const int _myRank = 47;

  @override
  Future<Result<PlayerStats>> getStats({String event = '3x3'}) async {
    await Future<void>.delayed(_latency);

    if (event != '3x3') {
      // Only 3x3 is in the MVP; other events have no solves behind them.
      return Ok<PlayerStats>(PlayerStats(event: event, solveCount: 0));
    }

    final List<StatsPoint> progress = _seedProgress();
    return Ok<PlayerStats>(
      PlayerStats(
        event: event,
        solveCount: progress.fold(
          0,
          (int sum, StatsPoint p) => sum + p.solveCount,
        ),
        bestSingleMs: 8420,
        bestAo5Ms: 10960,
        bestAo12Ms: 11540,
        bestAo100Ms: 12310,
        progress: progress,
        distribution: _seedDistribution(),
      ),
    );
  }

  @override
  Future<Result<Leaderboard>> getLeaderboard({
    String event = '3x3',
    LeaderboardMetric metric = LeaderboardMetric.single,
    LeaderboardScope scope = LeaderboardScope.global,
    String? cursor,
  }) async {
    await Future<void>.delayed(_latency);

    final List<LeaderboardEntry> all = _seedLeaderboard(metric, scope);

    final int start = int.tryParse(cursor ?? '0') ?? 0;
    if (start >= all.length) {
      return const Ok<Leaderboard>(
        Leaderboard(entries: <LeaderboardEntry>[]),
      );
    }
    final int end = (start + _pageSize).clamp(0, all.length);

    return Ok<Leaderboard>(
      Leaderboard(
        entries: all.sublist(start, end),
        currentUser: const LeaderboardEntry(
          userId: currentUserId,
          rank: _myRank,
          displayName: 'You',
          timeMs: 11200,
          countryCode: 'GB',
          isCurrentUser: true,
        ),
        nextCursor: end < all.length ? '$end' : null,
      ),
    );
  }

  @override
  Future<Result<PlayerProfile>> getPlayer(String userId) async {
    await Future<void>.delayed(_latency);

    final Iterable<_FakePlayer> matches =
        _players.where((_FakePlayer p) => p.id == userId);

    if (matches.isEmpty) {
      return const Err<PlayerProfile>(
        ServerFailure('That player could not be found.'),
      );
    }
    final _FakePlayer player = matches.first;

    return Ok<PlayerProfile>(
      PlayerProfile(
        userId: player.id,
        displayName: player.name,
        countryCode: player.country,
        elo: player.elo,
        bestSingleMs: player.singleMs,
        bestAo5Ms: player.singleMs + 2100,
        bestAo12Ms: player.singleMs + 2900,
        headToHead: HeadToHead(
          wins: player.h2hWins,
          losses: player.h2hLosses,
        ),
      ),
    );
  }

  // --- Seed data -------------------------------------------------------------

  static const List<_FakePlayer> _players = <_FakePlayer>[
    _FakePlayer('u1', 'Yuki Tanaka', 'JP', 5980, 1842, 1, 4),
    _FakePlayer('u2', 'Ana Silva', 'BR', 6310, 1798, 3, 2),
    _FakePlayer('u3', 'Tomas Novak', 'CZ', 6440, 1774, 0, 1),
    _FakePlayer('u4', 'Priya Nair', 'IN', 6720, 1731, 2, 2),
    _FakePlayer('u5', 'Lukas Meyer', 'DE', 6890, 1702, 5, 1),
    _FakePlayer('u6', 'Chen Wei', 'CN', 7040, 1688, 0, 0),
    _FakePlayer('u7', 'Sofia Rossi', 'IT', 7250, 1654, 1, 1),
    _FakePlayer('u8', 'Adam Kowalski', 'PL', 7480, 1621, 0, 3),
    _FakePlayer('u9', 'Mia Andersen', 'NO', 7690, 1599, 4, 0),
    _FakePlayer('u10', 'Omar Haddad', 'MA', 7910, 1570, 1, 2),
  ];

  List<LeaderboardEntry> _seedLeaderboard(
    LeaderboardMetric metric,
    LeaderboardScope scope,
  ) {
    // Friends is a much shorter board; country shorter still.
    final List<_FakePlayer> pool = switch (scope) {
      LeaderboardScope.global => _players,
      LeaderboardScope.friends => _players.take(4).toList(),
      LeaderboardScope.country => _players.take(6).toList(),
    };

    return <LeaderboardEntry>[
      for (int i = 0; i < pool.length; i++)
        LeaderboardEntry(
          userId: pool[i].id,
          rank: i + 1,
          displayName: pool[i].name,
          // An ao5 is always slower than a single.
          timeMs: metric == LeaderboardMetric.single
              ? pool[i].singleMs
              : pool[i].singleMs + 1800,
          countryCode: pool[i].country,
        ),
    ];
  }

  /// Three weeks of daily bests and averages, trending down.
  List<StatsPoint> _seedProgress() {
    final List<StatsPoint> points = <StatsPoint>[];

    const int days = 21;
    for (int dayAgo = days; dayAgo >= 0; dayAgo--) {
      if (_random.nextDouble() < 0.15) continue; // rest days

      final double progress = (days - dayAgo) / days;
      final double averageMs = 15500 - (3500 * progress);
      final double bestMs = averageMs * (0.78 + _random.nextDouble() * 0.08);

      points.add(
        StatsPoint(
          day: DateTime(_now.year, _now.month, _now.day)
              .subtract(Duration(days: dayAgo)),
          bestMs: bestMs.round(),
          averageMs: averageMs.round(),
          solveCount: 4 + _random.nextInt(8),
        ),
      );
    }
    return points;
  }

  /// A right-skewed distribution in one-second buckets — what a real solve
  /// histogram looks like: a peak, a short fast tail, a long slow one.
  List<HistogramBucket> _seedDistribution() {
    const List<int> counts = <int>[1, 4, 11, 23, 31, 26, 17, 9, 5, 3, 2, 1];
    const int startMs = 8000;

    return <HistogramBucket>[
      for (int i = 0; i < counts.length; i++)
        HistogramBucket(
          fromMs: startMs + i * 1000,
          toMs: startMs + (i + 1) * 1000,
          count: counts[i],
        ),
    ];
  }
}

class _FakePlayer {
  const _FakePlayer(
    this.id,
    this.name,
    this.country,
    this.singleMs,
    this.elo,
    this.h2hWins,
    this.h2hLosses,
  );

  final String id;
  final String name;
  final String country;
  final int singleMs;
  final int elo;

  /// Head-to-head from the signed-in user's perspective.
  final int h2hWins;
  final int h2hLosses;
}
