import 'package:cubeclash/features/timer/domain/entities/event_format.dart';
import 'package:cubeclash/features/timer/domain/entities/penalty.dart';
import 'package:cubeclash/features/timer/domain/entities/solve.dart';
import 'package:cubeclash/features/timer/domain/entities/solve_result.dart';
import 'package:cubeclash/features/timer/domain/entities/wca_event.dart';
import 'package:cubeclash/features/timer/domain/usecases/session_statistics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const SessionStatistics stats = SessionStatistics();
  final DateTime at = DateTime(2026, 7, 20, 10);

  Solve timed(String id, int ms, {Penalty penalty = Penalty.none}) => Solve(
        id: id,
        event: '3x3',
        scramble: 'R U',
        timeMs: ms,
        solvedAt: at,
        penalty: penalty,
      );

  List<SessionStat> statsOf(List<SessionStatValue> values) =>
      values.map((SessionStatValue v) => v.stat).toList();

  group('the cards follow the event, not the screen', () {
    test('3×3 keeps best · ao5 · ao12', () {
      final List<SessionStatValue> result = stats(WcaEvent.cube3x3, <Solve>[]);
      expect(
        statsOf(result),
        <SessionStat>[SessionStat.best, SessionStat.ao5, SessionStat.ao12],
      );
    });

    test('6×6 leads with its competition format', () {
      expect(
        statsOf(stats(WcaEvent.cube6x6, <Solve>[])),
        <SessionStat>[SessionStat.best, SessionStat.mo3, SessionStat.ao5],
      );
    });

    test('Multi-Blind shows no average at all', () {
      expect(
        statsOf(stats(WcaEvent.multiBlind, <Solve>[])),
        <SessionStat>[SessionStat.best, SessionStat.last, SessionStat.attempts],
      );
    });
  });

  group('computed values', () {
    test('best and ao5 over five solves', () {
      final List<Solve> solves = <Solve>[
        timed('a', 10000),
        timed('b', 11000),
        timed('c', 12000),
        timed('d', 13000),
        timed('e', 14000),
      ];
      final List<SessionStatValue> result = stats(WcaEvent.cube3x3, solves);

      expect(result[0].value, 10000);
      // ao5 trims 10000 and 14000, means 11000/12000/13000.
      expect(result[1].value, 12000);
      // Fewer than twelve solves — not "0.00", but "not yet".
      expect(result[2].value, isNull);
    });

    test('a DNF is trimmed as the slowest rather than poisoning the ao5', () {
      final List<Solve> solves = <Solve>[
        timed('a', 10000),
        timed('b', 11000),
        timed('c', 12000),
        timed('d', 13000),
        timed('e', 99000, penalty: Penalty.dnf),
      ];
      final List<SessionStatValue> result = stats(WcaEvent.cube3x3, solves);
      expect(result[0].value, 10000, reason: 'best ignores the DNF');
      expect(result[1].value, 12000, reason: 'the DNF is the trimmed slowest');
    });

    test('best skips DNFs entirely', () {
      final List<Solve> solves = <Solve>[
        timed('a', 5000, penalty: Penalty.dnf),
        timed('b', 11000),
      ];
      expect(stats(WcaEvent.cube3x3, solves)[0].value, 11000);
    });

    test('mo3 is untrimmed, so one DNF makes it a DNF', () {
      final List<Solve> solves = <Solve>[
        timed('a', 10000),
        timed('b', 11000),
        timed('c', 12000, penalty: Penalty.dnf),
      ];
      final List<SessionStatValue> result = stats(WcaEvent.cube6x6, solves);
      expect(result[1].stat, SessionStat.mo3);
      expect(result[1].value, isNull);
    });
  });

  group('Fewest Moves ranks on moves', () {
    Solve fmc(String id, int moves) => Solve(
          id: id,
          event: '3x3-fmc',
          scramble: 'R U',
          timeMs: 1800000,
          solvedAt: at,
          moveCount: moves,
        );

    test('best is the shortest solution, not the fastest attempt', () {
      final List<SessionStatValue> result = stats(
        WcaEvent.fewestMoves,
        <Solve>[fmc('a', 32), fmc('b', 26), fmc('c', 29)],
      );
      expect(result[0].value, 26);
      expect(result[0].kind, ResultKind.moveCount);
    });

    test('mo3 means the move counts', () {
      final List<SessionStatValue> result = stats(
        WcaEvent.fewestMoves,
        <Solve>[fmc('a', 24), fmc('b', 26), fmc('c', 28)],
      );
      expect(result[1].stat, SessionStat.mo3);
      expect(result[1].value, 26);
    });
  });

  group('Multi-Blind', () {
    Solve mbld(String id, int solved, int attempted, int ms) => Solve(
          id: id,
          event: '3x3-mbld',
          scramble: 'R U',
          timeMs: ms,
          solvedAt: at,
          solvedCount: solved,
          attemptedCount: attempted,
        );

    test('best is the most points, not the fastest attempt', () {
      final List<SessionStatValue> result = stats(
        WcaEvent.multiBlind,
        <Solve>[
          mbld('a', 6, 6, 900000), // 6 points, fast
          mbld('b', 11, 13, 3400000), // 9 points, slow
        ],
      );
      // The card renders the whole compound result, so it carries the result
      // rather than a bare integer.
      expect(result[0].result?.points, 9);
    });

    test('the attempts card counts every attempt, DNFs included', () {
      final List<SessionStatValue> result = stats(
        WcaEvent.multiBlind,
        <Solve>[
          mbld('a', 6, 6, 900000),
          mbld('b', 1, 4, 900000), // an automatic DNF under 9f12b
        ],
      );
      expect(result[2].stat, SessionStat.attempts);
      expect(result[2].value, 2);
      expect(result[2].isCount, isTrue);
    });

    test('last is the most recent attempt even when it was a DNF', () {
      final List<SessionStatValue> result = stats(
        WcaEvent.multiBlind,
        <Solve>[
          mbld('a', 6, 6, 900000),
          mbld('b', 1, 4, 900000),
        ],
      );
      expect(result[1].stat, SessionStat.last);
      expect(result[1].result?.isDnf, isTrue);
    });
  });

  group('an empty session', () {
    test('reports nothing rather than zero', () {
      for (final WcaEvent event in WcaEvent.all) {
        for (final SessionStatValue value in stats(event, <Solve>[])) {
          if (value.isCount) {
            expect(value.value, 0, reason: event.id);
          } else {
            expect(value.value, isNull, reason: event.id);
          }
        }
      }
    });
  });
}
