import 'dart:math';

import '../../../../core/demo/demo_seed.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/player_stats.dart';
import '../../domain/repositories/stats_repository.dart';

/// Seeded in-memory [StatsRepository] — see [FakeSolveRepository] for why the
/// fakes exist at all.
///
/// The per-event stats are rolled up from the shared [generateDemoHistory]
/// seeder, so every timed event has a real trend behind it and the numbers
/// agree with the Timer's history. The leaderboard is a ~60-deep board — ten
/// named elite plus generated filler — with the signed-in user parked at rank
/// 47 so both the "pin my row" behaviour and cursor pagination are exercised,
/// and its times scale per event off one set of 3×3 numbers.
class FakeStatsRepository implements StatsRepository {
  FakeStatsRepository({
    Random? random,
    DateTime? now,
    double readFailureRate = 0,
  })  : _random = random ?? Random(11),
        _now = now ?? DateTime.now(),
        _readFailureRate = readFailureRate;

  /// Drives jitter and the occasional simulated read failure. Kept separate
  /// from the roster's own seeding so a network hiccup on one call can never
  /// reshuffle the leaderboard on the next.
  final Random _random;
  final DateTime _now;

  /// How often a read pretends the network failed, so the error states are
  /// reachable in a demo. Defaults to 0 — the clean demo never errors; wire a
  /// small value in DI to show the retry UI off.
  final double _readFailureRate;

  static const Duration _latency = Duration(milliseconds: 260);
  static const String currentUserId = 'me';
  static const int _pageSize = 20;

  Future<void> _wait() => Future<void>.delayed(demoLatency(_latency, _random));

  bool get _readFails => _random.nextDouble() < _readFailureRate;

  static const ServerFailure _networkFailure =
      ServerFailure('Something went wrong. Pull to retry.');

  /// The signed-in user's rank. Deliberately well down the list.
  static const int _myRank = 47;

  @override
  Future<Result<PlayerStats>> getStats({String event = '3x3'}) async {
    await _wait();
    if (_readFails) return const Err<PlayerStats>(_networkFailure);

    // The very same seeded history the Timer's fake shows, rolled up into the
    // aggregate a real `GET /stats` would compute — so the headline bests here
    // match the solves listed there. Fewest Moves and Multi-Blind have no timed
    // history (they rank on moves / cubes), so they fall through to the empty
    // state rather than being charted in milliseconds.
    final List<DemoSolveSample> history = generateDemoHistory(event, now: _now);
    if (history.isEmpty) {
      return Ok<PlayerStats>(PlayerStats(event: event, solveCount: 0));
    }

    final DemoAggregate agg = aggregateDemoHistory(history);
    return Ok<PlayerStats>(
      PlayerStats(
        event: event,
        solveCount: agg.solveCount,
        bestSingleMs: agg.bestSingleMs,
        bestAo5Ms: agg.bestAo5Ms,
        bestAo12Ms: agg.bestAo12Ms,
        bestAo100Ms: agg.bestAo100Ms,
        progress: <StatsPoint>[
          for (final DemoDayPoint p in agg.progress)
            StatsPoint(
              day: p.day,
              bestMs: p.bestMs,
              averageMs: p.averageMs,
              solveCount: p.count,
            ),
        ],
        distribution: <HistogramBucket>[
          for (final DemoBucket b in agg.distribution)
            HistogramBucket(fromMs: b.fromMs, toMs: b.toMs, count: b.count),
        ],
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
    await _wait();
    if (_readFails) return const Err<Leaderboard>(_networkFailure);

    final List<LeaderboardEntry> all = _board(event, metric, scope);

    final int start = int.tryParse(cursor ?? '0') ?? 0;
    if (start >= all.length) {
      return const Ok<Leaderboard>(
        Leaderboard(entries: <LeaderboardEntry>[]),
      );
    }
    final int end = (start + _pageSize).clamp(0, all.length);

    // The user's own row travels with every page so the screen can pin it while
    // it is off-screen; once a page actually contains rank 47 the board's
    // `currentUserVisible` flips and the pin drops itself.
    final LeaderboardEntry me =
        all.firstWhere((LeaderboardEntry e) => e.userId == currentUserId);

    return Ok<Leaderboard>(
      Leaderboard(
        entries: all.sublist(start, end),
        currentUser: me,
        nextCursor: end < all.length ? '$end' : null,
      ),
    );
  }

  @override
  Future<Result<PlayerProfile>> getPlayer(String userId) async {
    await _wait();
    if (_readFails) return const Err<PlayerProfile>(_networkFailure);

    final Iterable<_FakePlayer> matches =
        _roster.where((_FakePlayer p) => p.id == userId);

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
        // Generated filler players have never raced you; only the named elite
        // carry a head-to-head, so a null record exercises the "never met" path.
        headToHead: player.h2hWins == 0 && player.h2hLosses == 0
            ? null
            : HeadToHead(wins: player.h2hWins, losses: player.h2hLosses),
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

  /// The full roster behind the leaderboard: the ten named elite above, plus
  /// generated filler so the global board is deep enough to actually page and
  /// for the rank-47 self-row to have neighbours to scroll past. Built once,
  /// deterministically. All times are 3×3 singles; [_board] scales them per
  /// event.
  late final List<_FakePlayer> _roster = _buildRoster();

  static const int _globalBoardSize = 60;

  List<_FakePlayer> _buildRoster() {
    // Its own RNG, so the board is identical no matter how many jittered reads
    // (which draw from `_random`) happened before it was first built.
    final Random rng = Random(11);
    final List<_FakePlayer> roster = <_FakePlayer>[..._players];

    int single = _players.last.singleMs;
    int elo = _players.last.elo;
    // Fill to one short of the board size — the sixtieth row is the user.
    for (int i = _players.length; i < _globalBoardSize - 1; i++) {
      single += 60 + rng.nextInt(160);
      elo -= 3 + rng.nextInt(9);
      roster.add(
        _FakePlayer(
          'g${i + 1}',
          _generatedName(i),
          _countryPool[rng.nextInt(_countryPool.length)],
          single,
          elo,
          0,
          0,
        ),
      );
    }
    return roster;
  }

  /// The ranked, event-scaled board for one query, with the signed-in user
  /// embedded at [_myRank].
  List<LeaderboardEntry> _board(
    String event,
    LeaderboardMetric metric,
    LeaderboardScope scope,
  ) {
    final double scale = _eventScale(event);
    final int aoOffset = (1800 * scale).round();
    int timeFor(int singleMs) =>
        ((metric == LeaderboardMetric.single ? singleMs : singleMs + aoOffset) *
                scale)
            .round();

    // Scope narrows the pool. Friends and country are short boards the user
    // sits inside, so their row shows inline and no pin is needed.
    final List<_FakePlayer> pool = switch (scope) {
      LeaderboardScope.global => _roster,
      LeaderboardScope.friends => _roster.take(6).toList(),
      LeaderboardScope.country =>
        _roster.where((_FakePlayer p) => p.country == 'GB').take(12).toList(),
    };

    // Where the user slots in: their fixed rank on the global board, or just
    // inside a short scoped board.
    final int userIndex = switch (scope) {
      LeaderboardScope.global => _myRank - 1,
      LeaderboardScope.friends => 3,
      LeaderboardScope.country => (pool.length / 2).floor(),
    }
        .clamp(0, pool.length);

    final List<LeaderboardEntry> rows = <LeaderboardEntry>[];
    int rank = 1;
    for (int i = 0; i <= pool.length; i++) {
      if (i == userIndex) {
        // The user's time interpolates between their neighbours so the row
        // sorts where its rank says it should.
        final int before =
            i == 0 ? timeFor(pool.first.singleMs) - 400 : rows.last.timeMs;
        final int after =
            i < pool.length ? timeFor(pool[i].singleMs) : before + 400;
        rows.add(
          LeaderboardEntry(
            userId: currentUserId,
            rank: rank++,
            displayName: 'You',
            timeMs: (before + after) ~/ 2,
            countryCode: 'GB',
            isCurrentUser: true,
          ),
        );
      }
      if (i == pool.length) break;
      rows.add(
        LeaderboardEntry(
          userId: pool[i].id,
          rank: rank++,
          displayName: pool[i].name,
          timeMs: timeFor(pool[i].singleMs),
          countryCode: pool[i].country,
        ),
      );
    }
    return rows;
  }

  /// How much slower a typical time is for [event] than for 3×3, used to scale
  /// the whole board off one set of 3×3 numbers. Events with no timed profile
  /// (Fewest Moves, Multi-Blind) fall back to 1.0.
  double _eventScale(String event) {
    final DemoEventProfile? profile = demoTimedEvents[event];
    final DemoEventProfile base = demoTimedEvents['3x3']!;
    if (profile == null) return 1;
    return profile.endMeanMs / base.endMeanMs;
  }

  String _generatedName(int i) {
    final String first = _firstNames[i % _firstNames.length];
    final String last = _lastNames[(i * 7) % _lastNames.length];
    return '$first $last';
  }

  static const List<String> _firstNames = <String>[
    'Liam',
    'Noah',
    'Emma',
    'Olivia',
    'Kai',
    'Aria',
    'Leo',
    'Zara',
    'Finn',
    'Nina',
    'Ivan',
    'Mei',
    'Diego',
    'Sara',
    'Ravi',
    'Elin',
    'Youssef',
    'Lena',
    'Marco',
    'Hana',
  ];

  static const List<String> _lastNames = <String>[
    'Park',
    'Muller',
    'Costa',
    'Ivanov',
    'Nguyen',
    'Khan',
    'Smith',
    'Dubois',
    'Rossi',
    'Kim',
    'Lopez',
    'Berg',
    'Hassan',
    'Ono',
    'Weber',
    'Reyes',
    'Fischer',
    'Marek',
  ];

  static const List<String> _countryPool = <String>[
    'US',
    'GB',
    'JP',
    'CN',
    'DE',
    'FR',
    'BR',
    'IN',
    'KR',
    'CA',
    'AU',
    'ES',
    'IT',
    'PL',
    'NL',
    'SE',
    'MX',
    'ZA',
  ];
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
