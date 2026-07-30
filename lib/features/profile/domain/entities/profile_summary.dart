import 'package:equatable/equatable.dart';

/// The composite read-model behind the "You · Profile" screen
/// (`GET /me/profile`). Every value the screen shows in one round trip.
///
/// Non-nullable where the contract guarantees a value (with the mapper
/// substituting the documented default) and deliberately nullable where the UI
/// drops or blanks a segment: [countryCode], [rank], [bestSingleMs] and
/// [winRate].
///
/// This carries only wire-shaped values — ms, a 0..1 ratio, an alpha-2 country
/// code, a rank number. All human formatting (2-dp seconds, "%", the country
/// name, thousands separators, the "#") is the UI's job.
class ProfileSummary extends Equatable {
  const ProfileSummary({
    required this.id,
    required this.displayName,
    required this.countryCode,
    required this.elo,
    required this.rank,
    required this.bestSingleMs,
    required this.bestSingleEvent,
    required this.totalSolves,
    required this.winRate,
    required this.wins,
    required this.losses,
    required this.friendCount,
  });

  final String id;
  final String displayName;

  /// ISO 3166-1 alpha-2 code (e.g. `UZ`), or null. Never a display name — the
  /// code → name mapping is a client display concern. Null → UI drops the
  /// country segment of the subtitle.
  final String? countryCode;

  /// Always rendered ("Elo {n}"). Stored on the server (default 1000); never
  /// recomputed for display.
  final int elo;

  /// The viewer's leaderboard rank for [rank]'s event/metric/scope, or null
  /// when they have no ranked solve there. Null → UI drops the "#…" segment.
  final ProfileRank? rank;

  /// Best single in [bestSingleEvent], in ms (DNF excluded), or null. Not a
  /// formatted string. Null → UI renders "—".
  final int? bestSingleMs;

  /// Echoes the event [bestSingleMs] is for, so the client never guesses.
  final String bestSingleEvent;

  /// COUNT of the user's non-deleted solves across all events. No separators
  /// here — the UI adds them.
  final int totalSolves;

  /// wins / (wins + losses) over settled races, as a 0..1 ratio, or null when
  /// wins + losses == 0. Not a percent. Null → UI renders "—".
  final double? winRate;

  final int wins;
  final int losses;

  /// COUNT of accepted friendships.
  final int friendCount;

  @override
  List<Object?> get props => <Object?>[
        id,
        displayName,
        countryCode,
        elo,
        rank,
        bestSingleMs,
        bestSingleEvent,
        totalSolves,
        winRate,
        wins,
        losses,
        friendCount,
      ];
}

/// The viewer's rank for one (event, metric, scope). Present only when they
/// have a ranked solve there — the whole object is nullable on [ProfileSummary].
class ProfileRank extends Equatable {
  const ProfileRank({
    required this.event,
    required this.metric,
    required this.scope,
    required this.position,
  });

  final String event;
  final String metric;
  final String scope;

  /// 1-based leaderboard position. A number, not "#1,204".
  final int position;

  @override
  List<Object?> get props => <Object?>[event, metric, scope, position];
}

/// The `rank_scope` query parameter — which leaderboard the profile rank reads.
/// The wire carries the Postgres enum form.
enum RankScope {
  global('global'),
  country('country'),
  friends('friends');

  const RankScope(this.wire);

  final String wire;
}
