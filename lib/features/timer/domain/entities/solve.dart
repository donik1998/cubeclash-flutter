import 'package:equatable/equatable.dart';

import 'penalty.dart';

/// A single solve record. Mirrors the `solves` table (docs → Data Model).
/// Pure Dart — no Flutter or IO imports — so it is trivially unit-testable.
class Solve extends Equatable {
  const Solve({
    required this.id,
    required this.event,
    required this.scramble,
    required this.timeMs,
    required this.solvedAt,
    this.penalty = Penalty.none,
  });

  final String id;
  final String event;
  final String scramble;

  /// Raw recorded time in milliseconds, before penalties.
  final int timeMs;
  final DateTime solvedAt;
  final Penalty penalty;

  /// Effective time with the penalty applied, in ms.
  /// Returns `null` for a DNF (it does not count toward averages).
  int? get effectiveTimeMs {
    switch (penalty) {
      case Penalty.none:
        return timeMs;
      case Penalty.plus2:
        return timeMs + 2000;
      case Penalty.dnf:
        return null;
    }
  }

  bool get isDnf => penalty == Penalty.dnf;

  Solve copyWith({Penalty? penalty}) => Solve(
        id: id,
        event: event,
        scramble: scramble,
        timeMs: timeMs,
        solvedAt: solvedAt,
        penalty: penalty ?? this.penalty,
      );

  @override
  List<Object?> get props =>
      <Object?>[id, event, scramble, timeMs, solvedAt, penalty];
}
