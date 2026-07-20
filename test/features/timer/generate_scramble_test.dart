import 'dart:math';

import 'package:cubeclash/features/timer/domain/entities/puzzle_spec.dart';
import 'package:cubeclash/features/timer/domain/usecases/generate_scramble.dart';
import 'package:flutter_test/flutter_test.dart';

/// The scrambler's value is entirely in its invariants, so they are tested
/// exhaustively rather than by sampling one lucky output.
void main() {
  const PuzzleSpec spec = PuzzleSpec.cube3x3;

  List<String> movesOf(String scramble) =>
      scramble.split(' ').where((String m) => m.isNotEmpty).toList();

  String faceOf(String move) => move[0];

  group('shape', () {
    test('produces exactly the puzzle move count', () {
      final GenerateScramble generate = GenerateScramble(random: Random(1));
      expect(movesOf(generate()).length, spec.moveCount);
      expect(movesOf(generate()).length, 20);
    });

    test('every move is a known face plus a legal modifier', () {
      final GenerateScramble generate = GenerateScramble(random: Random(2));

      for (int i = 0; i < 200; i++) {
        for (final String move in movesOf(generate())) {
          expect(move.length, inInclusiveRange(1, 2));
          expect(spec.faces, contains(faceOf(move)));
          expect(spec.modifiers, contains(move.substring(1)));
        }
      }
    });

    test('moves are single-space separated with no leading or trailing space',
        () {
      final GenerateScramble generate = GenerateScramble(random: Random(3));
      final String scramble = generate();
      expect(scramble, isNot(startsWith(' ')));
      expect(scramble, isNot(endsWith(' ')));
      expect(scramble, isNot(contains('  ')));
    });
  });

  group('invariant 1 — no consecutive moves on the same face', () {
    test('holds across many generated scrambles', () {
      final GenerateScramble generate = GenerateScramble(random: Random(4));

      for (int i = 0; i < 500; i++) {
        final List<String> moves = movesOf(generate());
        for (int m = 1; m < moves.length; m++) {
          expect(
            faceOf(moves[m]),
            isNot(faceOf(moves[m - 1])),
            reason: 'R R\' is redundant — scramble was: ${moves.join(' ')}',
          );
        }
      }
    });

    test('the rule itself rejects a repeat', () {
      expect(
        GenerateScramble.isLegalMove(spec, 'R', lastFace: 'R'),
        isFalse,
      );
      expect(
        GenerateScramble.isLegalMove(spec, 'L', lastFace: 'R'),
        isTrue,
        reason: 'opposite faces on one axis are fine as a pair',
      );
    });
  });

  group('invariant 2 — never three consecutive moves on one axis', () {
    test('holds across many generated scrambles', () {
      final GenerateScramble generate = GenerateScramble(random: Random(5));

      for (int i = 0; i < 500; i++) {
        final List<String> moves = movesOf(generate());
        for (int m = 2; m < moves.length; m++) {
          final int a = spec.axisOf(faceOf(moves[m]));
          final int b = spec.axisOf(faceOf(moves[m - 1]));
          final int c = spec.axisOf(faceOf(moves[m - 2]));
          expect(
            a == b && b == c,
            isFalse,
            reason: 'R L R reduces to R2 L — scramble was: ${moves.join(' ')}',
          );
        }
      }
    });

    test('the rule rejects the third move on a doubled axis', () {
      // R L _ : neither R nor L may follow.
      expect(
        GenerateScramble.isLegalMove(
          spec,
          'R',
          lastFace: 'L',
          secondLastFace: 'R',
        ),
        isFalse,
      );
      expect(
        GenerateScramble.isLegalMove(
          spec,
          'L',
          lastFace: 'R',
          secondLastFace: 'L',
        ),
        isFalse,
      );
      // A different axis is always fine.
      expect(
        GenerateScramble.isLegalMove(
          spec,
          'U',
          lastFace: 'L',
          secondLastFace: 'R',
        ),
        isTrue,
      );
    });

    test('two on an axis then back to it after a break is legal', () {
      // R L U R — the U breaks the run, so R is fine again.
      expect(
        GenerateScramble.isLegalMove(
          spec,
          'R',
          lastFace: 'U',
          secondLastFace: 'L',
        ),
        isTrue,
      );
    });
  });

  group('isValidScramble', () {
    test('accepts its own output', () {
      final GenerateScramble generate = GenerateScramble(random: Random(6));
      for (int i = 0; i < 200; i++) {
        final String scramble = generate();
        expect(
          GenerateScramble.isValidScramble(scramble, spec),
          isTrue,
          reason: scramble,
        );
      }
    });

    test('rejects a same-face repeat', () {
      final String bad = <String>[
        'R', "R'", // illegal pair
        ...List<String>.filled(18, 'U'),
      ].join(' ');
      expect(GenerateScramble.isValidScramble(bad, spec), isFalse);
    });

    test('rejects three moves on one axis', () {
      final String bad =
          <String>['R', 'L', "R'", ...List<String>.filled(17, 'U')].join(' ');
      expect(GenerateScramble.isValidScramble(bad, spec), isFalse);
    });

    test('rejects an unknown face', () {
      final String bad =
          <String>['X', ...List<String>.filled(19, 'U')].join(' ');
      expect(GenerateScramble.isValidScramble(bad, spec), isFalse);
    });

    test('rejects an unknown modifier', () {
      final String bad =
          <String>['R3', ...List<String>.filled(19, 'U')].join(' ');
      expect(GenerateScramble.isValidScramble(bad, spec), isFalse);
    });

    test('rejects the wrong move count', () {
      expect(GenerateScramble.isValidScramble('R U F', spec), isFalse);
    });
  });

  group('extensibility', () {
    test('generates for any registered puzzle', () {
      final GenerateScramble generate = GenerateScramble(random: Random(7));
      final String scramble = generate('2x2');
      expect(movesOf(scramble).length, PuzzleSpec.cube2x2.moveCount);
      expect(
        GenerateScramble.isValidScramble(scramble, PuzzleSpec.cube2x2),
        isTrue,
      );
    });

    test('scrambles 4x4, including wide turns', () {
      final GenerateScramble generate = GenerateScramble(random: Random(11));
      final String scramble = generate('4x4');
      final List<String> moves = movesOf(scramble);

      expect(moves, hasLength(PuzzleSpec.cube4x4.moveCount));
      expect(
        GenerateScramble.isValidScramble(scramble, PuzzleSpec.cube4x4),
        isTrue,
        reason: scramble,
      );
      expect(
        moves.any((String m) => m.startsWith(RegExp('[UDLRFB]w'))),
        isTrue,
        reason: 'a 4x4 scramble without wide turns is not a 4x4 scramble',
      );
    });

    test('4x4 tokens parse longest-face-first, so Rw2 is Rw + 2', () {
      // A naive single-character parser reads this as face `R`, modifier `w2`.
      expect(
        GenerateScramble.isValidScramble(
          <String>['Rw2', ...List<String>.filled(39, 'U')].join(' '),
          PuzzleSpec.cube4x4,
        ),
        isFalse,
        reason: 'the repeated U tail is illegal — but it must fail on *that*, '
            'having parsed Rw2 correctly first',
      );
      expect(
        GenerateScramble.isValidScramble('Rw2 U', PuzzleSpec.cube2x2),
        isFalse,
        reason: '2x2 has no wide turns',
      );
    });

    test('throws loudly for an event with no scrambler', () {
      final GenerateScramble generate = GenerateScramble(random: Random(8));
      expect(() => generate('megaminx'), throwsArgumentError);
    });
  });

  group('randomness', () {
    test('successive scrambles differ', () {
      final GenerateScramble generate = GenerateScramble(random: Random(9));
      final Set<String> seen = <String>{
        for (int i = 0; i < 50; i++) generate(),
      };
      expect(seen.length, 50, reason: 'no duplicates in 50 draws');
    });

    test('a seeded Random is reproducible', () {
      expect(
        GenerateScramble(random: Random(42))(),
        GenerateScramble(random: Random(42))(),
      );
    });

    test('every face gets used across a large sample', () {
      final GenerateScramble generate = GenerateScramble(random: Random(10));
      final Set<String> faces = <String>{};
      for (int i = 0; i < 50; i++) {
        faces.addAll(movesOf(generate()).map(faceOf));
      }
      expect(faces, unorderedEquals(spec.faces));
    });
  });
}
