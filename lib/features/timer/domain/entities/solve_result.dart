import 'package:equatable/equatable.dart';

import 'penalty.dart';

/// What kind of number an event's result actually is.
///
/// The app assumed [time] everywhere. Two events do not produce one.
enum ResultKind {
  /// Milliseconds. Every event except the two below.
  time,

  /// A move count — 3×3 Fewest Moves. There is a clock on an FMC attempt (one
  /// hour, Regulation E2) but it is not the result; the result is how short a
  /// solution you wrote down.
  moveCount,

  /// A compound result — 3×3 Multi-Blind: `11/13 in 54:22`. Ranked by points
  /// first, time second (Regulation 9f12).
  multiBlind,
}

/// A solve's result, in the shape its event actually produces.
///
/// ## Why `int timeMs` was not enough
///
/// `Solve.timeMs` still exists and still means what it always did — the
/// wall-clock duration of the attempt — because that is meaningful for every
/// one of the seventeen events, Fewest Moves and Multi-Blind included (both
/// are timed, they are just not *ranked* on the clock). What changes is that
/// `timeMs` stops being the **result** for those two, and this type is what
/// the rest of the app ranks, averages and renders.
///
/// ## Penalties
///
/// A `+2` is a time penalty and only a time penalty. Applying one to a Fewest
/// Moves move count would be nonsense, and Multi-Blind has no inspection to
/// overrun, so [supportsPlus2] is false for both — the penalty controls hide
/// the `+2` rather than offering a button that lies. A **DNF applies to every
/// event**: any attempt can fail.
class SolveResult extends Equatable {
  const SolveResult._({
    required this.kind,
    required this.timeMs,
    required this.penalty,
    this.moveCount,
    this.solvedCount,
    this.attemptedCount,
  });

  /// A timed result — the ordinary case.
  const SolveResult.time(int timeMs, {Penalty penalty = Penalty.none})
      : this._(kind: ResultKind.time, timeMs: timeMs, penalty: penalty);

  /// A Fewest Moves result: [moves] is the solution length, [timeMs] is how
  /// long the attempt took (informational — it never enters the ranking).
  const SolveResult.moves(
    int moves, {
    int timeMs = 0,
    Penalty penalty = Penalty.none,
  }) : this._(
          kind: ResultKind.moveCount,
          timeMs: timeMs,
          penalty: penalty,
          moveCount: moves,
        );

  /// A Multi-Blind result: [solved] of [attempted] cubes in [timeMs].
  const SolveResult.multiBlind({
    required int solved,
    required int attempted,
    required int timeMs,
    Penalty penalty = Penalty.none,
  }) : this._(
          kind: ResultKind.multiBlind,
          timeMs: timeMs,
          penalty: penalty,
          solvedCount: solved,
          attemptedCount: attempted,
        );

  final ResultKind kind;

  /// Wall-clock duration of the attempt, before any penalty.
  final int timeMs;

  final Penalty penalty;

  /// Solution length, [ResultKind.moveCount] only.
  final int? moveCount;

  /// [ResultKind.multiBlind] only.
  final int? solvedCount;
  final int? attemptedCount;

  /// Whether a `+2` is a coherent thing to apply. See the class doc.
  bool get supportsPlus2 => kind == ResultKind.time;

  /// Multi-Blind score: solved minus unsolved (Regulation 9f12a).
  int? get points => kind == ResultKind.multiBlind
      ? solvedCount! - (attemptedCount! - solvedCount!)
      : null;

  /// A Multi-Blind attempt is a DNF when fewer than two cubes are solved or
  /// the score is not positive (Regulation 9f12b) — even without the user
  /// marking it one.
  bool get isDnf {
    if (penalty == Penalty.dnf) return true;
    if (kind == ResultKind.multiBlind) {
      return solvedCount! < 2 || points! < 1;
    }
    return false;
  }

  /// The attempt duration with a time penalty applied, or `null` for a DNF.
  ///
  /// Unchanged in meaning from the old `Solve.effectiveTimeMs`, and still the
  /// number the timer prints — but for Fewest Moves and Multi-Blind it is no
  /// longer what the event is *ranked* on. Use [rank] for that.
  int? get effectiveTimeMs {
    if (isDnf) return null;
    return penalty == Penalty.plus2 && supportsPlus2 ? timeMs + 2000 : timeMs;
  }

  /// The value averages operate on: milliseconds for a timed event, moves for
  /// Fewest Moves, `null` for a DNF.
  ///
  /// Multi-Blind returns `null` always — averaging attempts that each chose a
  /// different number of cubes has no meaning, and its format is Best of X
  /// anyway (Regulation 9b5a), so nothing asks for one.
  int? get rankingValue => switch (kind) {
        ResultKind.time => effectiveTimeMs,
        ResultKind.moveCount => isDnf ? null : moveCount,
        ResultKind.multiBlind => null,
      };

  /// Orders two results best-first, across every kind.
  ///
  /// Lower is better for a time and for a move count. Multi-Blind inverts: more
  /// points wins, and only if the points tie does the faster attempt win
  /// (Regulation 9f12). A DNF always sorts last.
  int compareTo(SolveResult other) {
    if (isDnf || other.isDnf) {
      if (isDnf && other.isDnf) return 0;
      return isDnf ? 1 : -1;
    }
    if (kind == ResultKind.multiBlind && other.kind == ResultKind.multiBlind) {
      final int byPoints = other.points!.compareTo(points!);
      return byPoints != 0 ? byPoints : timeMs.compareTo(other.timeMs);
    }
    final int? a = rankingValue;
    final int? b = other.rankingValue;
    if (a == null || b == null) return 0;
    return a.compareTo(b);
  }

  SolveResult copyWith({Penalty? penalty}) => SolveResult._(
        kind: kind,
        timeMs: timeMs,
        penalty: penalty ?? this.penalty,
        moveCount: moveCount,
        solvedCount: solvedCount,
        attemptedCount: attemptedCount,
      );

  @override
  List<Object?> get props => <Object?>[
        kind,
        timeMs,
        penalty,
        moveCount,
        solvedCount,
        attemptedCount,
      ];
}
