import 'package:equatable/equatable.dart';

/// Which number the leaderboard ranks by.
enum LeaderboardMetric {
  single,
  ao5,
  ao12;

  /// Wire value for `?metric=` (docs → API Design): `single|ao5|ao12`.
  String get wire => name;

  String get label => switch (this) {
        LeaderboardMetric.single => 'Single',
        LeaderboardMetric.ao5 => 'Ao5',
        LeaderboardMetric.ao12 => 'Ao12',
      };
}

/// Who the leaderboard covers.
enum LeaderboardScope {
  global,
  friends,
  country;

  String get wire => name;

  String get label => switch (this) {
        LeaderboardScope.global => 'Global',
        LeaderboardScope.friends => 'Friends',
        LeaderboardScope.country => 'Country',
      };
}

/// One ranked row.
///
/// [rank] and [timeMs] both come from the server. The client renders them in
/// the order received and never re-sorts — ranking is server truth (docs → API
/// Design: "server owns is_pb, race results, ranking").
///
/// [timeMs] maps from the wire's `value_ms` — the metric's *ranking key*, not
/// raw `time_ms` (a `+2` is folded in, a DNF is excluded upstream). It is named
/// `timeMs` here because the UI formats it as a time; see the mapper.
///
/// There is deliberately **no avatar field** — the design's circle is a
/// placeholder rendered from initials, and the server exposes no avatar on a
/// leaderboard row (leaderboard spec §"no avatar field anywhere in the data
/// model").
class LeaderboardEntry extends Equatable {
  const LeaderboardEntry({
    required this.userId,
    required this.rank,
    required this.displayName,
    required this.timeMs,
    this.countryCode,
    this.isCurrentUser = false,
  });

  final String userId;
  final int rank;
  final String displayName;

  /// The metric's ranking value in milliseconds (wire `value_ms`).
  final int timeMs;

  /// ISO 3166-1 alpha-2 code, or null. Nullable through the whole pipeline: a
  /// row without a country renders without the country line.
  final String? countryCode;

  final bool isCurrentUser;

  @override
  List<Object?> get props => <Object?>[
        userId,
        rank,
        displayName,
        timeMs,
        countryCode,
        isCurrentUser,
      ];
}

/// A leaderboard page plus the viewer's own standing.
///
/// [viewer] is carried separately (it maps from the wire's top-level `viewer`
/// object, not from `items`) so the screen can pin the signed-in user's row to
/// the bottom when they fall outside the loaded range — the single most useful
/// thing a leaderboard can tell you is where *you* are. It is null when the
/// viewer has no ranked attempt.
class Leaderboard extends Equatable {
  const Leaderboard({
    required this.entries,
    this.viewer,
    this.nextCursor,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? viewer;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  /// Whether the viewer's row already appears in what's loaded — if so, pinning
  /// a second copy would be noise.
  bool get viewerVisible =>
      viewer != null &&
      entries.any((LeaderboardEntry e) => e.userId == viewer!.userId);

  @override
  List<Object?> get props => <Object?>[entries, viewer, nextCursor];
}

/// A public profile — `GET /users/:id`.
class PlayerProfile extends Equatable {
  const PlayerProfile({
    required this.userId,
    required this.displayName,
    this.countryCode,
    this.avatarUrl,
    this.elo,
    this.bestSingleMs,
    this.bestAo5Ms,
    this.bestAo12Ms,
    this.headToHead,
  });

  final String userId;
  final String displayName;
  final String? countryCode;
  final String? avatarUrl;

  /// Server-owned rating. Displayed, never computed here.
  final int? elo;

  final int? bestSingleMs;
  final int? bestAo5Ms;
  final int? bestAo12Ms;

  /// Race record against the signed-in user. Null when they've never met.
  final HeadToHead? headToHead;

  @override
  List<Object?> get props => <Object?>[
        userId,
        displayName,
        countryCode,
        avatarUrl,
        elo,
        bestSingleMs,
        bestAo5Ms,
        bestAo12Ms,
        headToHead,
      ];
}

/// Race record between the signed-in user and another player.
///
/// The *absence* of this object (a null `headToHead`) means the two have never
/// raced. A present record with `wins == 0 && losses == 0` is a different
/// state: they have raced, but nothing was decided -- the server counts a race
/// as a win or a loss only when someone actually won, so two mutual DNFs
/// produce exactly this. Never collapse the two.
class HeadToHead extends Equatable {
  const HeadToHead({required this.wins, required this.losses});

  /// Wins **for the signed-in user**.
  final int wins;
  final int losses;

  /// Races that produced a winner. **Not the number of races played** -- the
  /// server also tracks `dnf` and `left` outcomes and does not send them, so
  /// the true played count is not knowable from this payload. Label it as
  /// decided races, never as races.
  int get decided => wins + losses;

  @override
  List<Object?> get props => <Object?>[wins, losses];
}
