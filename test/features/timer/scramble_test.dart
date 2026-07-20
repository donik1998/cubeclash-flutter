import 'package:cubeclash/features/timer/domain/entities/scramble.dart';
import 'package:flutter_test/flutter_test.dart';

/// The scramble model exists because three notations lose meaning when
/// flattened to a space-separated string. These tests are that claim, made
/// executable.
void main() {
  group('face turns — the ordinary case', () {
    test('parses and round-trips exactly', () {
      const String raw = "R U2 F' L D R2 B'";
      final Scramble scramble = Scramble.parse(raw, ScrambleNotation.faceTurns);

      expect(scramble.lines, hasLength(1));
      expect(scramble.moveCount, 7);
      expect(scramble.text, raw);
      expect(
        Scramble.parse(scramble.text, ScrambleNotation.faceTurns),
        scramble,
      );
    });

    test('collapses runs of whitespace rather than emitting empty tokens', () {
      final Scramble scramble =
          Scramble.parse('  R   U2\t\tF\'  ', ScrambleNotation.faceTurns);
      expect(scramble.tokens, <String>['R', 'U2', "F'"]);
      expect(scramble.text, "R U2 F'");
    });

    test('parses a 100-move 7×7 scramble without losing a token', () {
      final String raw =
          List<String>.generate(100, (int i) => '3Rw${i % 3}').join(' ');
      expect(
        Scramble.parse(raw, ScrambleNotation.faceTurns).moveCount,
        100,
      );
    });
  });

  group('Megaminx — line breaks are semantic', () {
    // Seven lines of eleven moves, which is how TNoodle emits it and how
    // cubers execute it. Reflowing this into a paragraph is the failure the
    // structured model exists to prevent.
    const String megaminx = 'R++ D-- R++ D-- R-- D-- R++ D++ R++ D++ U\n'
        'R++ D-- R-- D++ R++ D++ R-- D-- R++ D-- U\n'
        "R-- D++ R++ D++ R-- D-- R++ D-- R-- D-- U'\n"
        'R++ D++ R-- D-- R++ D++ R++ D-- R++ D++ U\n'
        "R-- D-- R++ D-- R-- D++ R-- D++ R-- D-- U'\n"
        'R++ D-- R++ D++ R-- D-- R++ D-- R++ D++ U\n'
        "R-- D++ R-- D-- R++ D++ R-- D++ R++ D-- U'";

    test('keeps all seven lines separate', () {
      final Scramble scramble =
          Scramble.parse(megaminx, ScrambleNotation.faceTurns);

      expect(scramble.lines, hasLength(7));
      for (final List<String> line in scramble.lines) {
        expect(line, hasLength(11));
      }
      expect(scramble.moveCount, 77);
    });

    test('round-trips the line breaks byte for byte', () {
      final Scramble scramble =
          Scramble.parse(megaminx, ScrambleNotation.faceTurns);
      expect(scramble.text, megaminx);
      expect(scramble.text.split('\n'), hasLength(7));
    });

    test('survives a second round trip — which is what the wire does to it',
        () {
      final Scramble once =
          Scramble.parse(megaminx, ScrambleNotation.faceTurns);
      final Scramble twice =
          Scramble.parse(once.text, ScrambleNotation.faceTurns);
      expect(twice, once);
      expect(twice.lines, once.lines);
    });
  });

  group('Square-1 — slash-separated, never split on spaces', () {
    const String sq1 = '(1,0)/(6,0)/(-3,0)/(0,3)/(-5,-2)/';

    test('tokenises on the slash, not on whitespace', () {
      final Scramble scramble =
          Scramble.parse(sq1, ScrambleNotation.slashPairs);

      expect(scramble.tokens, <String>[
        '(1,0)/',
        '(6,0)/',
        '(-3,0)/',
        '(0,3)/',
        '(-5,-2)/',
      ]);
    });

    test('splitting on spaces would produce one token — the bug this fixes',
        () {
      expect(sq1.split(' '), hasLength(1));
      expect(
        Scramble.parse(sq1, ScrambleNotation.slashPairs).moveCount,
        5,
      );
    });

    test('the slash stays attached, so text round-trips without gaps', () {
      final Scramble scramble =
          Scramble.parse(sq1, ScrambleNotation.slashPairs);
      expect(scramble.text, sq1);
      expect(scramble.text, isNot(contains(' ')));
    });

    test('preserves a scramble with no trailing slash', () {
      const String noTrailing = '(1,0)/(6,0)/(-3,0)';
      final Scramble scramble =
          Scramble.parse(noTrailing, ScrambleNotation.slashPairs);
      expect(scramble.tokens.last, '(-3,0)');
      expect(scramble.text, noTrailing);
    });
  });

  group('Multi-Blind — a list of scrambles, not a scramble', () {
    const String multi = "R U R' U' F2 D B\n"
        "L2 F R' D2 U B2 L\n"
        "F' R2 D' L B U2 R";

    test('each line is an independent scramble', () {
      final Scramble scramble =
          Scramble.parse(multi, ScrambleNotation.multiScramble);
      expect(scramble.lines, hasLength(3));
      expect(scramble.isMultiScramble, isTrue);
    });

    test('numbers the cubes in the screen-reader label', () {
      final Scramble scramble =
          Scramble.parse(multi, ScrambleNotation.multiScramble);
      expect(scramble.semanticsLabel, startsWith('Cube 1:'));
      expect(scramble.semanticsLabel, contains('Cube 3:'));
    });

    test('round-trips', () {
      final Scramble scramble =
          Scramble.parse(multi, ScrambleNotation.multiScramble);
      expect(scramble.text, multi);
    });
  });

  group('the empty scramble', () {
    test('is what an event with no scrambler produces', () {
      const Scramble empty = Scramble.empty();
      expect(empty.isEmpty, isTrue);
      expect(empty.moveCount, 0);
      expect(empty.text, '');
      expect(empty.semanticsLabel, 'No scramble');
    });

    test('is what parsing blank input gives, rather than a bogus token', () {
      expect(
        Scramble.parse('   \n \n ', ScrambleNotation.faceTurns).isEmpty,
        isTrue,
      );
      expect(
        Scramble.parse('R U F', ScrambleNotation.none).isEmpty,
        isTrue,
      );
    });
  });

  group('the screen-reader label', () {
    test('separates tokens so R2 is not run into the next move', () {
      final Scramble scramble =
          Scramble.parse("R U2 F'", ScrambleNotation.faceTurns);
      expect(scramble.semanticsLabel, "Scramble: R, U2, F'");
    });

    test('pauses at a line break, where the notation does', () {
      final Scramble scramble =
          Scramble.parse('R U\nF D', ScrambleNotation.faceTurns);
      expect(scramble.semanticsLabel, 'Scramble: R, U. F, D');
    });
  });
}
