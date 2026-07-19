import 'package:equatable/equatable.dart';

/// One point on the progress chart — a day's best and average.
class StatsPoint extends Equatable {
  const StatsPoint({
    required this.day,
    required this.bestMs,
    required this.averageMs,
    required this.solveCount,
  });

  final DateTime day;
  final int bestMs;
  final int averageMs;
  final int solveCount;

  @override
  List<Object?> get props => <Object?>[day, bestMs, averageMs, solveCount];
}

/// One bar of the solve-time distribution.
class HistogramBucket extends Equatable {
  const HistogramBucket({
    required this.fromMs,
    required this.toMs,
    required this.count,
  });

  final int fromMs;
  final int toMs;
  final int count;

  @override
  List<Object?> get props => <Object?>[fromMs, toMs, count];
}

/// Aggregates for one event, as returned by `GET /stats?event=3x3`.
///
/// **Server-computed.** The client displays these; it does not derive them.
/// The docs are explicit that the server owns `is_pb` and ranking, and the same
/// reasoning applies to PBs — a personal best that two devices disagree about
/// is worse than one that takes a round trip.
///
/// Every average is nullable: a user with four solves has no ao5, and that is
/// "not yet", not zero.
class PlayerStats extends Equatable {
  const PlayerStats({
    required this.event,
    required this.solveCount,
    this.bestSingleMs,
    this.bestAo5Ms,
    this.bestAo12Ms,
    this.bestAo100Ms,
    this.progress = const <StatsPoint>[],
    this.distribution = const <HistogramBucket>[],
  });

  final String event;
  final int solveCount;

  final int? bestSingleMs;
  final int? bestAo5Ms;
  final int? bestAo12Ms;
  final int? bestAo100Ms;

  /// Oldest first — the chart reads left to right.
  final List<StatsPoint> progress;
  final List<HistogramBucket> distribution;

  /// Charts need a shape to draw. Below this the screen shows an empty state
  /// telling the user how many more solves they need, rather than rendering a
  /// two-point "trend" that means nothing.
  static const int minimumSolvesForCharts = 10;

  bool get hasEnoughForCharts => solveCount >= minimumSolvesForCharts;

  @override
  List<Object?> get props => <Object?>[
        event,
        solveCount,
        bestSingleMs,
        bestAo5Ms,
        bestAo12Ms,
        bestAo100Ms,
        progress,
        distribution,
      ];
}
