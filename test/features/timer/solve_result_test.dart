import 'package:cubeclash/features/timer/domain/entities/penalty.dart';
import 'package:cubeclash/features/timer/domain/entities/solve.dart';
import 'package:cubeclash/features/timer/domain/entities/solve_result.dart';
import 'package:cubeclash/features/timer/domain/usecases/format_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime at = DateTime(2026, 7, 20, 10);

  group('a timed result — unchanged behaviour', () {
    test('applies a +2 and reports a DNF as null', () {
      expect(const SolveResult.time(12340).effectiveTimeMs, 12340);
      expect(
        const SolveResult.time(12340, penalty: Penalty.plus2).effectiveTimeMs,
        14340,
      );
      expect(
        const SolveResult.time(12340, penalty: Penalty.dnf).effectiveTimeMs,
        isNull,
      );
    });

    test('ranks on the effective time', () {
      expect(const SolveResult.time(12340).rankingValue, 12340);
      expect(
        const SolveResult.time(12340, penalty: Penalty.plus2).rankingValue,
        14340,
      );
    });
  });

  group('Fewest Moves — a move count, not a time', () {
    test('ranks on moves and ignores the clock entirely', () {
      const SolveResult result = SolveResult.moves(28, timeMs: 3540000);
      expect(result.rankingValue, 28);
      expect(result.moveCount, 28);
      // The attempt was timed — an hour is the limit (Regulation E2) — but the
      // duration is informational, never the result.
      expect(result.timeMs, 3540000);
    });

    test('does not accept a +2, because two seconds is not a move', () {
      const SolveResult result = SolveResult.moves(28);
      expect(result.supportsPlus2, isFalse);
      // A +2 flag set anyway must not silently corrupt the ranking.
      const SolveResult penalised =
          SolveResult.moves(28, timeMs: 1000, penalty: Penalty.plus2);
      expect(penalised.rankingValue, 28);
      expect(penalised.effectiveTimeMs, 1000);
    });

    test('still accepts a DNF — any attempt can fail', () {
      const SolveResult result = SolveResult.moves(28, penalty: Penalty.dnf);
      expect(result.isDnf, isTrue);
      expect(result.rankingValue, isNull);
    });

    test('a solve with no move count recorded is a DNF, not a zero', () {
      final Solve solve = Solve(
        id: 'f1',
        event: '3x3-fmc',
        scramble: 'R U',
        timeMs: 600000,
        solvedAt: at,
      );
      expect(solve.result.kind, ResultKind.moveCount);
      expect(solve.isDnf, isTrue);
      expect(solve.rankingValue, isNull);
    });
  });

  group('Multi-Blind — a compound result (Regulation 9f12)', () {
    test('scores points as solved minus unsolved', () {
      const SolveResult r = SolveResult.multiBlind(
        solved: 11,
        attempted: 13,
        timeMs: 3262000,
      );
      expect(r.points, 9);
      expect(r.isDnf, isFalse);
    });

    test('is a DNF below two solved cubes, without anyone marking it', () {
      const SolveResult r =
          SolveResult.multiBlind(solved: 1, attempted: 3, timeMs: 600000);
      expect(r.isDnf, isTrue);
    });

    test('is a DNF when the score is not positive', () {
      // 2 solved of 5 → 2 - 3 = -1 points.
      const SolveResult r =
          SolveResult.multiBlind(solved: 2, attempted: 5, timeMs: 600000);
      expect(r.points, -1);
      expect(r.isDnf, isTrue);
    });

    test('has no ranking value, because it is never averaged', () {
      const SolveResult r = SolveResult.multiBlind(
        solved: 11,
        attempted: 13,
        timeMs: 3262000,
      );
      expect(r.rankingValue, isNull);
    });

    test('ranks on points first and time only as a tie-break', () {
      const SolveResult more = SolveResult.multiBlind(
        solved: 11,
        attempted: 13,
        timeMs: 3500000, // slower
      );
      const SolveResult fewer = SolveResult.multiBlind(
        solved: 6,
        attempted: 6,
        timeMs: 900000, // much faster
      );
      // More points wins despite being far slower.
      expect(more.compareTo(fewer), lessThan(0));

      const SolveResult tiedFast = SolveResult.multiBlind(
        solved: 11,
        attempted: 13,
        timeMs: 3000000,
      );
      expect(tiedFast.compareTo(more), lessThan(0));
    });

    test('a DNF always sorts last', () {
      const SolveResult ok = SolveResult.time(12000);
      const SolveResult dnf = SolveResult.time(9000, penalty: Penalty.dnf);
      expect(ok.compareTo(dnf), lessThan(0));
      expect(dnf.compareTo(ok), greaterThan(0));
    });
  });

  group('formatting across the whole range', () {
    test('seconds, minutes, ten minutes, hours', () {
      expect(FormatResult.formatTime(1234), '1.23');
      expect(FormatResult.formatTime(83450), '1:23.45');
      // WCA 9f2 — ten minutes and up drops the hundredths.
      expect(FormatResult.formatTime(600000), '10:00');
      expect(FormatResult.formatTime(3262000), '54:22');
      expect(FormatResult.formatTime(3600000), '1:00:00');
    });

    test('a move count is bare; a move mean carries two decimals', () {
      expect(FormatResult.formatMoves(28), '28');
      expect(FormatResult.formatMovesMean(25.666), '25.67');
    });

    test('a Multi-Blind result reads as cubers write it', () {
      expect(
        FormatResult.formatMultiBlind(
          solved: 11,
          attempted: 13,
          timeMs: 3262000,
        ),
        '11/13 in 54:22',
      );
    });

    test('display dispatches on the result kind', () {
      expect(const SolveResult.time(12340), isNotNull);
      expect(FormatResult.display(const SolveResult.time(12340)), '12.34');
      expect(
        FormatResult.display(
          const SolveResult.time(12340, penalty: Penalty.plus2),
        ),
        '14.34+',
      );
      expect(FormatResult.display(const SolveResult.moves(28)), '28');
      expect(
        FormatResult.display(
          const SolveResult.multiBlind(
            solved: 11,
            attempted: 13,
            timeMs: 3262000,
          ),
        ),
        '11/13 in 54:22',
      );
      expect(
        FormatResult.display(
          const SolveResult.time(12340, penalty: Penalty.dnf),
        ),
        'DNF',
      );
    });

    test('the screen reader gets units, not glyphs', () {
      expect(
        FormatResult.semanticsFor(const SolveResult.moves(28)),
        '28 moves',
      );
      expect(
        FormatResult.semanticsFor(
          const SolveResult.multiBlind(
            solved: 11,
            attempted: 13,
            timeMs: 3262000,
          ),
        ),
        '11 of 13 cubes solved in 54:22',
      );
    });
  });

  group('Solve keeps a time for every event', () {
    test('a Multi-Blind solve carries its counts alongside the duration', () {
      final Solve solve = Solve(
        id: 'm1',
        event: '3x3-mbld',
        scramble: 'R U\nF D',
        timeMs: 3262000,
        solvedAt: at,
        solvedCount: 11,
        attemptedCount: 13,
      );
      expect(solve.result.kind, ResultKind.multiBlind);
      expect(solve.result.points, 9);
      expect(solve.effectiveTimeMs, 3262000);
      expect(solve.isDnf, isFalse);
    });

    test('copyWith preserves the long-form fields', () {
      final Solve solve = Solve(
        id: 'm1',
        event: '3x3-mbld',
        scramble: 'R U',
        timeMs: 3262000,
        solvedAt: at,
        solvedCount: 11,
        attemptedCount: 13,
      );
      final Solve dnf = solve.copyWith(penalty: Penalty.dnf);
      expect(dnf.solvedCount, 11);
      expect(dnf.attemptedCount, 13);
      expect(dnf.isDnf, isTrue);
    });
  });
}
