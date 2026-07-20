import 'package:equatable/equatable.dart';

import 'penalty.dart';
import 'solve_result.dart';
import 'wca_event.dart';

/// A single solve record. Mirrors the `solves` table (docs → Data Model).
/// Pure Dart — no Flutter or IO imports — so it is trivially unit-testable.
///
/// ## Shape across seventeen events
///
/// [timeMs] and [scramble] stay exactly what they were, because both are
/// meaningful for every event: even Fewest Moves and Multi-Blind are timed,
/// they are simply not *ranked* on the clock. What the two long-form events
/// add is a second number — a move count, or a solved/attempted pair — and
/// those arrive as the three nullable columns below.
///
/// The useful consequence: nothing that only reads a time (history, the stats
/// charts, the race) had to change, and `POST /solves` grows three optional
/// fields rather than changing the meaning of an existing one. Use [result] to
/// get the event-correct result rather than reading [timeMs] and guessing.
class Solve extends Equatable {
  const Solve({
    required this.id,
    required this.event,
    required this.scramble,
    required this.timeMs,
    required this.solvedAt,
    this.penalty = Penalty.none,
    this.moveCount,
    this.solvedCount,
    this.attemptedCount,
  });

  final String id;
  final String event;

  /// The scramble as a string — newline-separated where the event's notation
  /// has significant line breaks. See `Scramble` for why the wire format
  /// stayed a string and what `\n` now guarantees.
  final String scramble;

  /// Raw recorded time in milliseconds, before penalties. For Fewest Moves and
  /// Multi-Blind this is how long the attempt took, not the result.
  final int timeMs;
  final DateTime solvedAt;
  final Penalty penalty;

  /// Solution length — 3×3 Fewest Moves only.
  final int? moveCount;

  /// Cubes solved / attempted — 3×3 Multi-Blind only.
  final int? solvedCount;
  final int? attemptedCount;

  /// The event's own definition of this solve's result.
  SolveResult get result {
    final WcaEvent spec = WcaEvent.fromId(event);
    switch (spec.resultKind) {
      case ResultKind.moveCount:
        // A move count that never arrived means the attempt was recorded
        // without a solution, which is precisely a DNF.
        return moveCount == null
            ? SolveResult.moves(0, timeMs: timeMs, penalty: Penalty.dnf)
            : SolveResult.moves(moveCount!, timeMs: timeMs, penalty: penalty);
      case ResultKind.multiBlind:
        return SolveResult.multiBlind(
          solved: solvedCount ?? 0,
          attempted: attemptedCount ?? 0,
          timeMs: timeMs,
          penalty: penalty,
        );
      case ResultKind.time:
        return SolveResult.time(timeMs, penalty: penalty);
    }
  }

  /// Effective time with the penalty applied, in ms.
  /// Returns `null` for a DNF (it does not count toward averages).
  int? get effectiveTimeMs => result.effectiveTimeMs;

  /// What averages and personal bests rank on — milliseconds for a timed
  /// event, moves for Fewest Moves, `null` for a DNF or for Multi-Blind (which
  /// is not an averaged event).
  int? get rankingValue => result.rankingValue;

  bool get isDnf => result.isDnf;

  Solve copyWith({Penalty? penalty}) => Solve(
        id: id,
        event: event,
        scramble: scramble,
        timeMs: timeMs,
        solvedAt: solvedAt,
        penalty: penalty ?? this.penalty,
        moveCount: moveCount,
        solvedCount: solvedCount,
        attemptedCount: attemptedCount,
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        event,
        scramble,
        timeMs,
        solvedAt,
        penalty,
        moveCount,
        solvedCount,
        attemptedCount,
      ];
}
