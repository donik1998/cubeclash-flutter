import 'package:equatable/equatable.dart';

/// Where a tournament is in its life.
enum TournamentStatus {
  upcoming,
  live,
  finished;

  String get label => switch (this) {
        TournamentStatus.upcoming => 'UPCOMING',
        TournamentStatus.live => 'LIVE',
        TournamentStatus.finished => 'FINISHED',
      };
}

/// A tournament, as the lobby lists it.
///
/// **Server-owned in production.** Entrant counts, live status and results all
/// come from the backend; the fake seeds a plausible slate so the Tournaments
/// tab is a real feature rather than a wall of `SOON` badges. The UI labels it
/// as demo data so nothing pretends a real competition is running.
class Tournament extends Equatable {
  const Tournament({
    required this.id,
    required this.name,
    required this.event,
    required this.status,
    required this.entrants,
    required this.capacity,
    required this.startsAt,
    required this.description,
    this.registered = false,
  });

  final String id;
  final String name;

  /// The `WcaEvent.id` it's raced on.
  final String event;
  final TournamentStatus status;
  final int entrants;
  final int capacity;
  final DateTime startsAt;
  final String description;

  /// Whether the signed-in user has entered. Server truth; the fake toggles it
  /// locally so the register flow is demoable.
  final bool registered;

  bool get isFull => entrants >= capacity;

  Tournament copyWith({bool? registered, int? entrants}) => Tournament(
        id: id,
        name: name,
        event: event,
        status: status,
        entrants: entrants ?? this.entrants,
        capacity: capacity,
        startsAt: startsAt,
        description: description,
        registered: registered ?? this.registered,
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        name,
        event,
        status,
        entrants,
        capacity,
        startsAt,
        description,
        registered,
      ];
}

/// A full tournament view — the header plus its bracket.
class TournamentDetail extends Equatable {
  const TournamentDetail({required this.tournament, required this.rounds});

  final Tournament tournament;

  /// Earliest round first (e.g. Round of 16 → … → Final).
  final List<TournamentRound> rounds;

  @override
  List<Object?> get props => <Object?>[tournament, rounds];
}

/// One round of a single-elimination bracket.
class TournamentRound extends Equatable {
  const TournamentRound({required this.name, required this.matches});

  final String name;
  final List<TournamentMatch> matches;

  @override
  List<Object?> get props => <Object?>[name, matches];
}

/// One head-to-head in the bracket. Times are null before the match is solved;
/// [winner] is the winning seat, or null while pending.
class TournamentMatch extends Equatable {
  const TournamentMatch({
    required this.playerA,
    required this.playerB,
    this.timeAMs,
    this.timeBMs,
    this.winner,
  });

  final String playerA;
  final String playerB;
  final int? timeAMs;
  final int? timeBMs;

  /// `'A'`, `'B'`, or null when the match hasn't been played.
  final String? winner;

  bool get isPlayed => winner != null;

  @override
  List<Object?> get props =>
      <Object?>[playerA, playerB, timeAMs, timeBMs, winner];
}
