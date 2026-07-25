import 'package:equatable/equatable.dart';

/// The signed-in user's racing standing, as the lobby header and Quick Match
/// card show it — `GET /race/summary` (proposed).
///
/// **Server-owned.** Elo, rank and win rate are the server's to compute; the
/// Race bloc never derives them. Kept off the lobby until now precisely because
/// there was no endpoint and stitching it client-side would have been a guess.
/// The fake now supplies it so the frame's Elo pill, stats row and rivals list
/// have real values to render.
class LobbySummary extends Equatable {
  const LobbySummary({
    required this.elo,
    required this.globalRank,
    required this.wins,
    required this.losses,
    this.bestSingleMs,
    this.ao5Ms,
    this.recentRivals = const <Rival>[],
  });

  final int elo;
  final int globalRank;
  final int wins;
  final int losses;
  final int? bestSingleMs;
  final int? ao5Ms;
  final List<Rival> recentRivals;

  int get totalRaces => wins + losses;

  /// Win rate as a percentage 0–100, or null with no races behind it.
  int? get winRate =>
      totalRaces == 0 ? null : ((wins / totalRaces) * 100).round();

  @override
  List<Object?> get props => <Object?>[
        elo,
        globalRank,
        wins,
        losses,
        bestSingleMs,
        ao5Ms,
        recentRivals,
      ];
}

/// A recent opponent and your record against them.
class Rival extends Equatable {
  const Rival({
    required this.userId,
    required this.displayName,
    required this.wins,
    required this.losses,
    this.countryCode,
  });

  final String userId;
  final String displayName;
  final int wins;
  final int losses;
  final String? countryCode;

  @override
  List<Object?> get props =>
      <Object?>[userId, displayName, wins, losses, countryCode];
}
