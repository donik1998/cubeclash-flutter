/// Shared demo-data seeder for the fake repositories.
///
/// **Why this lives in `core/demo` and not in a feature.** Two fakes need the
/// same numbers: `FakeSolveRepository` turns a seeded history into `Solve`
/// rows, and `FakeStatsRepository` turns the *same* history into the aggregate
/// a real `GET /stats` would compute. Before this existed each fake made up its
/// own constants, so a demo's Stats headline (`best 8.42`) had nothing to do
/// with the solves in the history list. Deriving both from one deterministic
/// series makes the screens reconcile — which is the whole point of a
/// convincing demo.
///
/// Pure Dart, and deliberately free of any feature import: it speaks in neutral
/// value types ([DemoPenalty], [DemoSolveSample], [DemoAggregate]) that each
/// repository maps onto its own domain entities. `core` never depends on a
/// feature, so the dependency arrow stays correct.
///
/// It covers the fifteen **timed** events. Fewest Moves and Multi-Blind are
/// ranked on a move count and a cube count, not a clock, so a millisecond
/// progress chart is the wrong renderer for them — seeding them here would feed
/// the Stats charts numbers they would mislabel. Their history is a separate
/// piece of work; see the Timer feature's manual-entry flow.
library;

import 'dart:math';

/// Neutral penalty, mapped onto each feature's own `Penalty` by the repository.
enum DemoPenalty { none, plus2, dnf }

/// One seeded attempt — the atom both fakes are built from.
class DemoSolveSample {
  const DemoSolveSample({
    required this.solvedAt,
    required this.timeMs,
    required this.penalty,
  });

  final DateTime solvedAt;

  /// Raw attempt duration in ms, before any penalty.
  final int timeMs;
  final DemoPenalty penalty;

  /// The time a ranking/average operates on: `null` for a DNF, `+2000` for a
  /// `+2`, otherwise the raw time. Mirrors `SolveResult.effectiveTimeMs` so the
  /// two never drift.
  int? get effectiveTimeMs => switch (penalty) {
        DemoPenalty.dnf => null,
        DemoPenalty.plus2 => timeMs + 2000,
        DemoPenalty.none => timeMs,
      };
}

/// Per-event tuning: where a typical single sits now, where it sat three weeks
/// ago (so the trend slopes down), and how often penalties land.
///
/// Blindfolded events carry a high [dnfRate] on purpose — a third of blind
/// attempts failing is what the discipline actually looks like, and it makes
/// the DNF handling in the averages visible in the demo.
class DemoEventProfile {
  const DemoEventProfile({
    required this.startMeanMs,
    required this.endMeanMs,
    this.plusRate = 0.04,
    this.dnfRate = 0.015,
  });

  final int startMeanMs;
  final int endMeanMs;
  final double plusRate;
  final double dnfRate;
}

/// The fifteen timed events with demo history behind them, keyed by
/// `WcaEvent.id`. Means are ballpark-realistic for a mid-level cuber.
const Map<String, DemoEventProfile> demoTimedEvents =
    <String, DemoEventProfile>{
  '2x2': DemoEventProfile(startMeanMs: 4600, endMeanMs: 3500),
  '3x3': DemoEventProfile(startMeanMs: 15500, endMeanMs: 12000),
  '4x4': DemoEventProfile(startMeanMs: 54000, endMeanMs: 42000),
  '5x5': DemoEventProfile(startMeanMs: 98000, endMeanMs: 78000),
  '6x6': DemoEventProfile(startMeanMs: 182000, endMeanMs: 145000),
  '7x7': DemoEventProfile(startMeanMs: 262000, endMeanMs: 210000),
  '3x3-oh': DemoEventProfile(startMeanMs: 29000, endMeanMs: 22000),
  'clock': DemoEventProfile(startMeanMs: 11500, endMeanMs: 9000),
  'megaminx': DemoEventProfile(startMeanMs: 70000, endMeanMs: 55000),
  'pyraminx': DemoEventProfile(startMeanMs: 8600, endMeanMs: 6500),
  'skewb': DemoEventProfile(startMeanMs: 9800, endMeanMs: 7500),
  'square-1': DemoEventProfile(startMeanMs: 18500, endMeanMs: 14000),
  // Blindfolded: slower, and far more likely to DNF.
  '3x3-bld': DemoEventProfile(
    startMeanMs: 120000,
    endMeanMs: 95000,
    plusRate: 0,
    dnfRate: 0.34,
  ),
  '4x4-bld': DemoEventProfile(
    startMeanMs: 400000,
    endMeanMs: 320000,
    plusRate: 0,
    dnfRate: 0.42,
  ),
  '5x5-bld': DemoEventProfile(
    startMeanMs: 760000,
    endMeanMs: 620000,
    plusRate: 0,
    dnfRate: 0.5,
  ),
};

/// Whether [eventId] has a seeded demo history.
bool hasDemoHistory(String eventId) => demoTimedEvents.containsKey(eventId);

/// A jittered version of [base], between 0.6× and 1.6× — so the fakes' loading
/// states vary the way a real network does rather than flashing past at an
/// identical, tell-tale constant every time.
Duration demoLatency(Duration base, Random random) =>
    base * (0.6 + random.nextDouble());

/// A stable per-event seed, so that any caller — the solve fake or the stats
/// fake — that asks for [eventId]'s history gets the **same** sequence and the
/// two screens reconcile. Derived from the event's position in the profile
/// table rather than `String.hashCode`, which is not a contract to depend on.
int _seedFor(String eventId) {
  final int index = demoTimedEvents.keys.toList().indexOf(eventId);
  return 1000 + index * 17;
}

/// A deterministic three-week practice history for [eventId], newest first.
///
/// Seeded from the event id alone (see [_seedFor]) so it is identical no matter
/// which fake calls it — that shared determinism is what makes the Timer
/// history and the Stats aggregate agree. Returns `const []` for an event with
/// no profile (Fewest Moves, Multi-Blind, or any unknown id), so a caller can
/// seed every event and simply get nothing for the two that are not timed.
List<DemoSolveSample> generateDemoHistory(
  String eventId, {
  required DateTime now,
  int days = 21,
}) {
  final DemoEventProfile? profile = demoTimedEvents[eventId];
  if (profile == null) return const <DemoSolveSample>[];

  final Random random = Random(_seedFor(eventId));
  final List<DemoSolveSample> samples = <DemoSolveSample>[];
  for (int dayAgo = days; dayAgo >= 0; dayAgo--) {
    // Some days you don't cube.
    if (random.nextDouble() < 0.15) continue;

    final int count = 4 + random.nextInt(8);
    final double progress = (days - dayAgo) / days;
    final double meanMs = profile.startMeanMs -
        (profile.startMeanMs - profile.endMeanMs) * progress;

    for (int i = 0; i < count; i++) {
      final DateTime solvedAt = now.subtract(
        Duration(days: dayAgo, hours: random.nextInt(6), minutes: i * 3),
      );
      samples.add(
        DemoSolveSample(
          solvedAt: solvedAt,
          timeMs: _sampleTimeMs(meanMs, random),
          penalty: _samplePenalty(profile, random),
        ),
      );
    }
  }

  samples.sort(
    (DemoSolveSample a, DemoSolveSample b) => b.solvedAt.compareTo(a.solvedAt),
  );
  return samples;
}

/// A right-skewed time around [meanMs]: most solves cluster, a few are much
/// slower (a bad case), none are impossibly fast.
int _sampleTimeMs(double meanMs, Random random) {
  final double base =
      meanMs * (0.78 + (random.nextDouble() + random.nextDouble()) * 0.22);
  final double tail =
      random.nextDouble() < 0.08 ? random.nextDouble() * meanMs * 0.6 : 0;
  final int floor = (meanMs * 0.4).round();
  return (base + tail).round().clamp(floor, (meanMs * 4).round());
}

DemoPenalty _samplePenalty(DemoEventProfile profile, Random random) {
  final double roll = random.nextDouble();
  if (roll < profile.dnfRate) return DemoPenalty.dnf;
  if (roll < profile.dnfRate + profile.plusRate) return DemoPenalty.plus2;
  return DemoPenalty.none;
}

// --- Aggregation -------------------------------------------------------------

/// One day of the progress chart, in neutral form.
class DemoDayPoint {
  const DemoDayPoint({
    required this.day,
    required this.bestMs,
    required this.averageMs,
    required this.count,
  });

  final DateTime day;
  final int bestMs;
  final int averageMs;
  final int count;
}

/// One bar of the distribution histogram, in neutral form.
class DemoBucket {
  const DemoBucket({
    required this.fromMs,
    required this.toMs,
    required this.count,
  });

  final int fromMs;
  final int toMs;
  final int count;
}

/// The server-side aggregate a real `GET /stats` would compute, derived here
/// from the very same [DemoSolveSample]s the history is built from — so the
/// numbers on the two screens agree.
class DemoAggregate {
  const DemoAggregate({
    required this.solveCount,
    required this.bestSingleMs,
    required this.bestAo5Ms,
    required this.bestAo12Ms,
    required this.bestAo100Ms,
    required this.progress,
    required this.distribution,
  });

  final int solveCount;
  final int? bestSingleMs;
  final int? bestAo5Ms;
  final int? bestAo12Ms;
  final int? bestAo100Ms;

  /// Oldest first — the chart reads left to right.
  final List<DemoDayPoint> progress;
  final List<DemoBucket> distribution;
}

/// Rolls a seeded history up into the aggregate the Stats screen renders.
DemoAggregate aggregateDemoHistory(List<DemoSolveSample> samples) {
  if (samples.isEmpty) {
    return const DemoAggregate(
      solveCount: 0,
      bestSingleMs: null,
      bestAo5Ms: null,
      bestAo12Ms: null,
      bestAo100Ms: null,
      progress: <DemoDayPoint>[],
      distribution: <DemoBucket>[],
    );
  }

  // Oldest first, the order averages are computed in.
  final List<DemoSolveSample> chrono = samples.reversed.toList();
  final List<int?> effective =
      chrono.map((DemoSolveSample s) => s.effectiveTimeMs).toList();

  final Iterable<int> finished = effective.whereType<int>();
  final int? bestSingle = finished.isEmpty
      ? null
      : finished.reduce((int a, int b) => a < b ? a : b);

  return DemoAggregate(
    solveCount: samples.length,
    bestSingleMs: bestSingle,
    bestAo5Ms: _bestRollingAverage(effective, 5),
    bestAo12Ms: _bestRollingAverage(effective, 12),
    bestAo100Ms: _bestRollingAverage(effective, 100),
    progress: _progressByDay(chrono),
    distribution: bestSingle == null
        ? const <DemoBucket>[]
        : _distribution(finished.toList()),
  );
}

/// The best WCA average over any window of [window] consecutive solves.
///
/// Each window drops its single best and single worst (5 % each side once the
/// window reaches 100, per WCA 9f9), and a DNF sorts as the worst — so one DNF
/// in five is absorbed, but two make the whole average a DNF (returned as a
/// skipped window).
int? _bestRollingAverage(List<int?> effective, int window) {
  if (effective.length < window) return null;
  final int trim = window >= 100 ? window ~/ 20 : 1;

  int? best;
  for (int i = 0; i + window <= effective.length; i++) {
    final int? avg = _trimmedMean(effective.sublist(i, i + window), trim);
    if (avg != null && (best == null || avg < best)) best = avg;
  }
  return best;
}

/// Trimmed mean of one window: sort ascending with DNFs (null) last, drop
/// [trim] from each end, mean the rest. Null when more than [trim] DNFs remain
/// after the top trim would have removed them.
int? _trimmedMean(List<int?> window, int trim) {
  final int dnfs = window.where((int? t) => t == null).length;
  if (dnfs > trim) return null;

  final List<int> finished = window.whereType<int>().toList()..sort();
  // The DNFs occupy the worst `dnfs` of the top-trim slots; the remaining
  // top-trim slots come off the finished times.
  final int trimTopFromFinished = trim - dnfs;
  final int start = trim;
  final int end = finished.length - trimTopFromFinished;
  if (end <= start) return null;

  final List<int> middle = finished.sublist(start, end);
  final int sum = middle.fold(0, (int a, int b) => a + b);
  return (sum / middle.length).round();
}

List<DemoDayPoint> _progressByDay(List<DemoSolveSample> chrono) {
  final Map<DateTime, List<DemoSolveSample>> byDay =
      <DateTime, List<DemoSolveSample>>{};
  for (final DemoSolveSample s in chrono) {
    final DateTime day =
        DateTime(s.solvedAt.year, s.solvedAt.month, s.solvedAt.day);
    byDay.putIfAbsent(day, () => <DemoSolveSample>[]).add(s);
  }

  final List<DateTime> days = byDay.keys.toList()..sort();
  final List<DemoDayPoint> points = <DemoDayPoint>[];
  for (final DateTime day in days) {
    final List<int> finished = byDay[day]!
        .map((DemoSolveSample s) => s.effectiveTimeMs)
        .whereType<int>()
        .toList();
    if (finished.isEmpty) continue; // an all-DNF day has no point to plot
    final int best = finished.reduce((int a, int b) => a < b ? a : b);
    final int average =
        (finished.fold(0, (int a, int b) => a + b) / finished.length).round();
    points.add(
      DemoDayPoint(
        day: day,
        bestMs: best,
        averageMs: average,
        count: byDay[day]!.length,
      ),
    );
  }
  return points;
}

/// A twelve-bucket histogram spanning the finished times.
List<DemoBucket> _distribution(List<int> finished) {
  const int buckets = 12;
  final int min = finished.reduce((int a, int b) => a < b ? a : b);
  final int max = finished.reduce((int a, int b) => a > b ? a : b);
  // Round the span out to a whole number of buckets so the edges read cleanly.
  final int rawWidth = ((max - min) / buckets).ceil();
  final int width = rawWidth < 1 ? 1 : rawWidth;

  final List<int> counts = List<int>.filled(buckets, 0);
  for (final int t in finished) {
    final int idx = ((t - min) ~/ width).clamp(0, buckets - 1);
    counts[idx]++;
  }

  return <DemoBucket>[
    for (int i = 0; i < buckets; i++)
      DemoBucket(
        fromMs: min + i * width,
        toMs: min + (i + 1) * width,
        count: counts[i],
      ),
  ];
}
