import 'package:cubeclash/core/demo/demo_seed.dart';
import 'package:cubeclash/features/stats/data/repositories/fake_stats_repository.dart';
import 'package:cubeclash/features/stats/domain/entities/leaderboard_entry.dart';
import 'package:cubeclash/features/timer/data/repositories/fake_solve_repository.dart';
import 'package:cubeclash/features/timer/domain/entities/solve.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime(2026, 7, 21);

  group('generateDemoHistory', () {
    test('is deterministic — same event, same series', () {
      final List<DemoSolveSample> a = generateDemoHistory('3x3', now: now);
      final List<DemoSolveSample> b = generateDemoHistory('3x3', now: now);

      expect(a.length, b.length);
      expect(a.length, greaterThan(50));
      for (int i = 0; i < a.length; i++) {
        expect(a[i].timeMs, b[i].timeMs);
        expect(a[i].penalty, b[i].penalty);
      }
    });

    test('covers the fifteen timed events and only those', () {
      for (final String id in demoTimedEvents.keys) {
        expect(generateDemoHistory(id, now: now), isNotEmpty, reason: id);
      }
      // Fewest Moves and Multi-Blind rank on moves / cubes, not a clock.
      expect(generateDemoHistory('3x3-fmc', now: now), isEmpty);
      expect(generateDemoHistory('3x3-mbld', now: now), isEmpty);
      expect(generateDemoHistory('nonsense', now: now), isEmpty);
    });

    test('is newest-first', () {
      final List<DemoSolveSample> h = generateDemoHistory('4x4', now: now);
      for (int i = 1; i < h.length; i++) {
        expect(
          h[i].solvedAt.isAfter(h[i - 1].solvedAt),
          isFalse,
          reason: 'sample $i is newer than the one before it',
        );
      }
    });

    test('blindfolded events DNF far more often than a 2×2', () {
      double dnfRate(String id) {
        final List<DemoSolveSample> h = generateDemoHistory(id, now: now);
        final int dnf =
            h.where((DemoSolveSample s) => s.penalty == DemoPenalty.dnf).length;
        return dnf / h.length;
      }

      expect(dnfRate('3x3-bld'), greaterThan(0.2));
      expect(dnfRate('2x2'), lessThan(0.1));
    });
  });

  group('aggregateDemoHistory', () {
    test('bests are monotonic: single ≤ ao5 ≤ ao12 ≤ ao100', () {
      final DemoAggregate agg =
          aggregateDemoHistory(generateDemoHistory('3x3', now: now));

      expect(agg.bestSingleMs, isNotNull);
      expect(agg.bestSingleMs!, lessThanOrEqualTo(agg.bestAo5Ms!));
      expect(agg.bestAo5Ms!, lessThanOrEqualTo(agg.bestAo12Ms!));
      expect(agg.bestAo12Ms!, lessThanOrEqualTo(agg.bestAo100Ms!));
    });

    test('an average is null when the window has too many DNFs', () {
      // A 50%-DNF event cannot form a clean ao100 (needs ≤5 DNFs in 100).
      final DemoAggregate agg =
          aggregateDemoHistory(generateDemoHistory('5x5-bld', now: now));
      expect(agg.bestAo100Ms, isNull);
    });

    test('best single equals the fastest finished sample', () {
      final List<DemoSolveSample> h = generateDemoHistory('3x3', now: now);
      final int fastest = h
          .map((DemoSolveSample s) => s.effectiveTimeMs)
          .whereType<int>()
          .reduce((int a, int b) => a < b ? a : b);
      expect(aggregateDemoHistory(h).bestSingleMs, fastest);
    });
  });

  group('the fakes reconcile off the shared seed', () {
    test('Stats best matches the fastest solve the Timer history shows',
        () async {
      final FakeSolveRepository solves = FakeSolveRepository(now: now);
      final FakeStatsRepository stats = FakeStatsRepository(now: now);
      addTearDown(solves.dispose);

      final List<Solve> history =
          (await solves.getHistory(event: '4x4')).valueOrNull!.items;
      // A page holds 20; the full seeded history is deeper, so pull the fastest
      // from the whole seed rather than one page.
      final int seedFastest = generateDemoHistory('4x4', now: now)
          .map((DemoSolveSample s) => s.effectiveTimeMs)
          .whereType<int>()
          .reduce((int a, int b) => a < b ? a : b);

      final int? statsBest =
          (await stats.getStats(event: '4x4')).valueOrNull!.bestSingleMs;

      expect(history, isNotEmpty);
      expect(statsBest, seedFastest);
    });

    test('non-3×3 events are no longer hollow', () async {
      final FakeStatsRepository stats = FakeStatsRepository(now: now);
      for (final String id in <String>['2x2', '4x4', '3x3-oh', 'megaminx']) {
        final int count =
            (await stats.getStats(event: id)).valueOrNull!.solveCount;
        expect(count, greaterThan(0), reason: id);
      }
    });
  });

  group('leaderboard', () {
    test('is deep enough to page, with the user embedded at their rank',
        () async {
      final FakeStatsRepository stats = FakeStatsRepository(now: now);

      final Leaderboard first = (await stats.getLeaderboard()).valueOrNull!;
      expect(first.entries.length, greaterThan(10));
      expect(first.hasMore, isTrue,
          reason: 'first page should not be the last');
      expect(first.viewerVisible, isFalse,
          reason: 'rank 47 is below the first page, so the pin should show');

      // Page to the end; the user row must appear so the pin retires.
      String? cursor = first.nextCursor;
      bool sawUser = false;
      while (cursor != null) {
        final Leaderboard page =
            (await stats.getLeaderboard(cursor: cursor)).valueOrNull!;
        sawUser = sawUser ||
            page.entries.any((LeaderboardEntry e) => e.isCurrentUser);
        cursor = page.nextCursor;
      }
      expect(sawUser, isTrue);
    });

    test('scales times per event — 4×4 board is slower than 2×2', () async {
      final FakeStatsRepository stats = FakeStatsRepository(now: now);
      final int top2x2 = (await stats.getLeaderboard(event: '2x2'))
          .valueOrNull!
          .entries
          .first
          .timeMs;
      final int top4x4 = (await stats.getLeaderboard(event: '4x4'))
          .valueOrNull!
          .entries
          .first
          .timeMs;
      expect(top4x4, greaterThan(top2x2));
    });
  });

  group('failure knob', () {
    test('reads never fail at rate 0 (the clean demo)', () async {
      final FakeStatsRepository stats = FakeStatsRepository(now: now);
      for (int i = 0; i < 20; i++) {
        expect((await stats.getStats()).isOk, isTrue);
        expect((await stats.getLeaderboard()).isOk, isTrue);
      }
    });

    test('reads fail every time at rate 1', () async {
      final FakeStatsRepository stats =
          FakeStatsRepository(now: now, readFailureRate: 1);
      expect((await stats.getStats()).isOk, isFalse);
      expect((await stats.getLeaderboard()).isOk, isFalse);
      expect((await stats.getPlayer('u1')).isOk, isFalse);
    });
  });
}
