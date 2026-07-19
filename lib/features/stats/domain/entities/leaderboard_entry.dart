import 'package:equatable/equatable.dart';

/// Which number the leaderboard ranks by.
enum LeaderboardMetric {
  single,
  ao5;

  /// Wire value for `?metric=` (docs → API Design).
  String get wire => name;

  String get label => switch (this) {
        LeaderboardMetric.single => 'Single',
        LeaderboardMetric.ao5 => 'Ao5',
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
class LeaderboardEntry extends Equatable {
  const LeaderboardEntry({
    required this.userId,
    required this.rank,
    required this.displayName,
    required this.timeMs,
    this.countryCode,
    this.avatarUrl,
    this.isCurrentUser = false,
  });

  final String userId;
  final int rank;
  final String displayName;
  final int timeMs;
  final String? countryCode;
  final String? avatarUrl;
  final bool isCurrentUser;

  @override
  List<Object?> get props => <Object?>[
        userId,
        rank,
        displayName,
        timeMs,
        countryCode,
        avatarUrl,
        isCurrentUser,
      ];
}

/// A leaderboard page plus the current user's own standing.
///
/// [currentUser] is carried separately so the screen can pin their row to the
/// bottom when they fall outside the loaded range — the single most useful
/// thing a leaderboard can tell you is where *you* are.
class Leaderboard extends Equatable {
  const Leaderboard({
    required this.entries,
    this.currentUser,
    this.nextCursor,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentUser;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  /// Whether the current user's row already appears in what's loaded — if so,
  /// pinning a second copy would be noise.
  bool get currentUserVisible =>
      currentUser != null &&
      entries.any((LeaderboardEntry e) => e.userId == currentUser!.userId);

  @override
  List<Object?> get props => <Object?>[entries, currentUser, nextCursor];
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
class HeadToHead extends Equatable {
  const HeadToHead({required this.wins, required this.losses});

  /// Wins **for the signed-in user**.
  final int wins;
  final int losses;

  int get total => wins + losses;

  @override
  List<Object?> get props => <Object?>[wins, losses];
}
