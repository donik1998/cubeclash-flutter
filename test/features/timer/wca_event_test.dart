import 'package:cubeclash/features/timer/domain/entities/event_format.dart';
import 'package:cubeclash/features/timer/domain/entities/puzzle_spec.dart';
import 'package:cubeclash/features/timer/domain/entities/scramble.dart';
import 'package:cubeclash/features/timer/domain/entities/solve_result.dart';
import 'package:cubeclash/features/timer/domain/entities/wca_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// The event table is the spine of the whole feature, so it is tested against
/// the Regulations rather than against itself: each assertion names the
/// regulation it encodes, so a future edit that contradicts §9b fails here
/// with a pointer to the authority.
void main() {
  group('the event set', () {
    test('is exactly the seventeen official WCA events', () {
      expect(WcaEvent.all, hasLength(17));
    });

    test('has no duplicate ids', () {
      final Set<String> ids = WcaEvent.all.map((WcaEvent e) => e.id).toSet();
      expect(ids, hasLength(WcaEvent.all.length));
    });

    test('keeps the ids already in the database', () {
      // Existing solves carry these. Switching to the WCA's own `333`/`444`
      // codes would orphan every row written before this change.
      expect(WcaEvent.cube3x3.id, '3x3');
      expect(WcaEvent.cube4x4.id, '4x4');
    });

    test('resolves an unknown id to 3×3 rather than throwing', () {
      // A server that grows an eighteenth event before the client does must
      // not crash the timer.
      expect(WcaEvent.fromId('4x4-oh'), WcaEvent.cube3x3);
      expect(WcaEvent.fromId(null), WcaEvent.cube3x3);
      expect(WcaEvent.isKnown('4x4-oh'), isFalse);
    });

    test('every event resolves back from its own id', () {
      for (final WcaEvent event in WcaEvent.all) {
        expect(WcaEvent.fromId(event.id), event, reason: event.id);
      }
    });
  });

  group('competition formats (Regulation 9b)', () {
    test('9b1a — Average of 5 for the ten standard events', () {
      const List<WcaEvent> ao5 = <WcaEvent>[
        WcaEvent.cube2x2,
        WcaEvent.cube3x3,
        WcaEvent.cube4x4,
        WcaEvent.cube5x5,
        WcaEvent.oneHanded,
        WcaEvent.clock,
        WcaEvent.megaminx,
        WcaEvent.pyraminx,
        WcaEvent.skewb,
        WcaEvent.square1,
      ];
      expect(ao5, hasLength(10));
      for (final WcaEvent event in ao5) {
        expect(event.format, EventFormat.ao5, reason: event.id);
      }
    });

    test('9b2a — Mean of 3 for 6×6 and 7×7', () {
      expect(WcaEvent.cube6x6.format, EventFormat.mo3);
      expect(WcaEvent.cube7x7.format, EventFormat.mo3);
    });

    test('9b3a — Best of 3 for the three blindfolded events', () {
      for (final WcaEvent event in WcaEvent.inGroup(EventGroup.blindfolded)) {
        expect(event.format, EventFormat.bo3, reason: event.id);
      }
      expect(WcaEvent.inGroup(EventGroup.blindfolded), hasLength(3));
    });

    test('9b5a — Multi-Blind is a Best of X, so one attempt is the unit', () {
      expect(WcaEvent.multiBlind.format, EventFormat.bo1);
      expect(EventFormat.bo1.attempts, 1);
    });
  });

  group('session stat cards per format', () {
    test('an Ao5 event keeps the frame\'s best · ao5 · ao12', () {
      expect(
        EventFormat.ao5.sessionStats,
        <SessionStat>[SessionStat.best, SessionStat.ao5, SessionStat.ao12],
      );
    });

    test('an Mo3 event leads with the competition format', () {
      // 6×6/7×7/FMC: mo3 is the round, ao5 is the practice trend, and ao12 is
      // dropped because twelve three-minute solves is most of an hour.
      expect(
        EventFormat.mo3.sessionStats,
        <SessionStat>[SessionStat.best, SessionStat.mo3, SessionStat.ao5],
      );
    });

    test('a Bo3 event shows both rankings the WCA recognises', () {
      // 9b3a ranks on the best; 9b3b also recognises a mean of 3.
      expect(
        EventFormat.bo3.sessionStats,
        <SessionStat>[SessionStat.best, SessionStat.mo3, SessionStat.ao5],
      );
    });

    test('Multi-Blind shows no average, because averaging it is meaningless',
        () {
      final List<SessionStat> stats = EventFormat.bo1.sessionStats;
      expect(stats, isNot(contains(SessionStat.ao5)));
      expect(stats, isNot(contains(SessionStat.mo3)));
      expect(stats, <SessionStat>[
        SessionStat.best,
        SessionStat.last,
        SessionStat.attempts,
      ]);
    });

    test('every format shows exactly three cards', () {
      for (final EventFormat format in EventFormat.values) {
        expect(format.sessionStats, hasLength(3), reason: format.name);
      }
    });

    test(
        'every format leads with best — the one stat that always means the '
        'same thing', () {
      for (final EventFormat format in EventFormat.values) {
        expect(format.sessionStats.first, SessionStat.best);
      }
    });
  });

  group('scramblers', () {
    test('all seventeen have one', () {
      // Twelve puzzle-backed events, plus Megaminx and Clock (fixed-pattern),
      // plus Pyraminx and Skewb (random-state), plus Square-1 (random-move) —
      // every event can now be scrambled.
      expect(WcaEvent.scramblable, hasLength(17));
      expect(
        WcaEvent.all.every((WcaEvent e) => e.hasScrambler),
        isTrue,
      );
    });

    test('the modifier events scramble on their base puzzle', () {
      expect(WcaEvent.oneHanded.puzzle, PuzzleSpec.cube3x3);
      expect(WcaEvent.blind3x3.puzzle, PuzzleSpec.cube3x3);
      expect(WcaEvent.fewestMoves.puzzle, PuzzleSpec.cube3x3);
      expect(WcaEvent.multiBlind.puzzle, PuzzleSpec.cube3x3);
      expect(WcaEvent.blind4x4.puzzle, PuzzleSpec.cube4x4);
      expect(WcaEvent.blind5x5.puzzle, PuzzleSpec.cube5x5);
    });
  });

  group('raceability', () {
    test('excludes everything without a scrambler', () {
      for (final WcaEvent event in WcaEvent.raceableEvents) {
        expect(event.hasScrambler, isTrue, reason: event.id);
      }
    });

    test('excludes blindfolded, Fewest Moves and Multi-Blind', () {
      final List<String> raceable =
          WcaEvent.raceableEvents.map((WcaEvent e) => e.id).toList();
      expect(raceable, isNot(contains('3x3-bld')));
      expect(raceable, isNot(contains('4x4-bld')));
      expect(raceable, isNot(contains('5x5-bld')));
      expect(raceable, isNot(contains('3x3-fmc')));
      expect(raceable, isNot(contains('3x3-mbld')));
    });

    test('quick match is a strict subset of raceable', () {
      final Set<String> raceable =
          WcaEvent.raceableEvents.map((WcaEvent e) => e.id).toSet();
      for (final WcaEvent event in WcaEvent.quickMatchEvents) {
        expect(raceable, contains(event.id), reason: event.id);
      }
      expect(
        WcaEvent.quickMatchEvents.length,
        lessThan(WcaEvent.raceableEvents.length),
      );
    });

    test('quick match offers only short, populated events', () {
      // A 6×6 quick match would search a pool that is realistically empty.
      expect(
        WcaEvent.quickMatchEvents.map((WcaEvent e) => e.id),
        unorderedEquals(<String>['2x2', '3x3', '3x3-oh']),
      );
    });
  });

  group('result kinds', () {
    test('only Fewest Moves is scored on move count', () {
      final List<WcaEvent> moves = WcaEvent.all
          .where((WcaEvent e) => e.resultKind == ResultKind.moveCount)
          .toList();
      expect(moves, <WcaEvent>[WcaEvent.fewestMoves]);
      expect(WcaEvent.fewestMoves.isManualEntry, isTrue);
    });

    test('only Multi-Blind is a compound result', () {
      final List<WcaEvent> multi = WcaEvent.all
          .where((WcaEvent e) => e.resultKind == ResultKind.multiBlind)
          .toList();
      expect(multi, <WcaEvent>[WcaEvent.multiBlind]);
    });

    test('Multi-Blind is N scrambles, not one', () {
      expect(WcaEvent.multiBlind.scrambleCount, greaterThan(1));
      expect(WcaEvent.multiBlind.notation, ScrambleNotation.multiScramble);
    });

    test('Square-1 declares its notation even without a scrambler yet', () {
      // A server-supplied Square-1 scramble must already parse correctly.
      expect(WcaEvent.square1.notation, ScrambleNotation.slashPairs);
    });

    test('the hour-limited events are the two long-form ones', () {
      expect(WcaEvent.fewestMoves.attemptLimit, const Duration(hours: 1));
      expect(WcaEvent.multiBlind.attemptLimit, const Duration(hours: 1));
    });
  });
}
