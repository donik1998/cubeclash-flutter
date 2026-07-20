import '../entities/event_format.dart';
import '../entities/solve.dart';
import '../entities/solve_result.dart';
import '../entities/wca_event.dart';
import 'compute_averages.dart';

/// One computed session statistic, ready to render.
///
/// Carries the raw [value] *and* the [kind] it should be formatted as, because
/// the same card slot shows a time for 3×3, a move count for Fewest Moves and
/// a plain integer for the solve count — and the widget must not have to
/// re-derive which.
class SessionStatValue {
  const SessionStatValue({
    required this.stat,
    required this.value,
    required this.kind,
    this.result,
    this.isCount = false,
  });

  final SessionStat stat;

  /// `null` means "not enough solves yet", which renders as `—` rather than a
  /// zero. Fewer than five solves is not an ao5 of 0.00.
  final int? value;

  final ResultKind kind;

  /// The whole result behind this card, where one exists — `best` and `last`
  /// point at a specific attempt, and averages do not.
  ///
  /// Multi-Blind needs it: `11/13 in 54:22` cannot be reconstructed from a
  /// single integer, so the card renders this rather than [value].
  final SolveResult? result;

  /// A tally rather than a result — formatted as a bare integer, and never
  /// "not enough solves yet".
  final bool isCount;
}

/// Computes the three cards under the timer for whichever event is selected.
///
/// **Why this is a use case and not three getters on the state.** Which three
/// statistics to show is a rule of the *event*, not of the screen — the format
/// picks them ([EventFormat.sessionStats]) — and what each one means depends
/// on the result kind. Both are domain concerns, and both need testing against
/// event tables rather than against widgets.
class SessionStatistics {
  const SessionStatistics({ComputeAverages averages = const ComputeAverages()})
      : _averages = averages;

  final ComputeAverages _averages;

  /// The cards for [event], computed over [solves] (oldest first).
  List<SessionStatValue> call(WcaEvent event, List<Solve> solves) {
    // Rank on the event's own result value: milliseconds for a timed event,
    // moves for Fewest Moves. A DNF is `null`, which ComputeAverages already
    // treats as the slowest possible attempt.
    final List<int?> values =
        solves.map((Solve s) => s.rankingValue).toList(growable: false);

    final Solve? best = _bestOf(solves);
    // `last` is the most recent attempt whatever it was — a DNF is a real
    // result and hiding it would misreport the session.
    final Solve? last = solves.isEmpty ? null : solves.last;

    return <SessionStatValue>[
      for (final SessionStat stat in event.format.sessionStats)
        switch (stat) {
          SessionStat.attempts => SessionStatValue(
              stat: stat,
              value: solves.length,
              kind: event.resultKind,
              isCount: true,
            ),
          SessionStat.best => _fromSolve(stat, best, event),
          SessionStat.last => _fromSolve(stat, last, event),
          SessionStat.ao5 =>
            _fromAverage(stat, _averages.average(values, 5), event),
          SessionStat.ao12 =>
            _fromAverage(stat, _averages.average(values, 12), event),
          SessionStat.mo3 =>
            _fromAverage(stat, _averages.mean(values, 3), event),
        },
    ];
  }

  SessionStatValue _fromSolve(SessionStat stat, Solve? solve, WcaEvent event) =>
      SessionStatValue(
        stat: stat,
        value: solve?.rankingValue,
        kind: event.resultKind,
        result: solve?.result,
      );

  SessionStatValue _fromAverage(SessionStat stat, int? value, WcaEvent event) =>
      SessionStatValue(stat: stat, value: value, kind: event.resultKind);

  /// The best result in [solves], by the event's own ordering.
  ///
  /// Goes through [SolveResult.compareTo] rather than `min` over the ranking
  /// values, because Multi-Blind inverts: more points wins, and only a tie on
  /// points is broken by the faster time. Sorting a list of milliseconds could
  /// never express that.
  Solve? _bestOf(List<Solve> solves) {
    final List<Solve> finished =
        solves.where((Solve s) => !s.isDnf).toList(growable: false);
    if (finished.isEmpty) return null;

    Solve best = finished.first;
    for (final Solve solve in finished.skip(1)) {
      if (solve.result.compareTo(best.result) < 0) best = solve;
    }
    return best;
  }
}
