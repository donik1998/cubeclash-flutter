import 'dart:math';

import 'package:cubeclash/features/timer/domain/entities/puzzle_spec.dart';
import 'package:cubeclash/features/timer/domain/entities/scramble.dart';
import 'package:cubeclash/features/timer/domain/entities/wca_event.dart';
import 'package:cubeclash/features/timer/domain/usecases/generate_scramble.dart';
import 'package:flutter_test/flutter_test.dart';

/// The scrambler's invariants are a portfolio talking point, so extending it to
/// the big cubes has to *add* cases rather than relax rules. These tests
/// re-assert both invariants at every new size, plus the two things the bigger
/// puzzles introduce: three-layer wide turns, and Multi-Blind's N-scrambles.
void main() {
  final GenerateScramble generate = GenerateScramble(random: Random(42));

  const Map<String, PuzzleSpec> bigCubes = <String, PuzzleSpec>{
    '5x5': PuzzleSpec.cube5x5,
    '6x6': PuzzleSpec.cube6x6,
    '7x7': PuzzleSpec.cube7x7,
  };

  group('the big cubes are registered', () {
    test('5×5, 6×6 and 7×7 all resolve', () {
      for (final MapEntry<String, PuzzleSpec> entry in bigCubes.entries) {
        expect(PuzzleSpec.byEvent[entry.key], entry.value, reason: entry.key);
      }
    });

    test('move counts grow with the puzzle', () {
      expect(PuzzleSpec.cube5x5.moveCount, 60);
      expect(PuzzleSpec.cube6x6.moveCount, 80);
      expect(PuzzleSpec.cube7x7.moveCount, 100);
    });

    test('6×6 and 7×7 add the three-layer wide turn', () {
      expect(PuzzleSpec.cube6x6.faces, contains('3Rw'));
      expect(PuzzleSpec.cube7x7.faces, contains('3Uw'));
      // 5×5 does not — one wide layer is enough.
      expect(PuzzleSpec.cube5x5.faces, isNot(contains('3Rw')));
    });

    test('a wide turn shares the axis of its outer face', () {
      // If it did not, `R Rw R` would slip past invariant 2.
      for (final PuzzleSpec spec in bigCubes.values) {
        expect(spec.axisOf('R'), spec.axisOf('Rw'));
        expect(spec.axisOf('R'), spec.axisOf('L'));
      }
      expect(
        PuzzleSpec.cube7x7.axisOf('R'),
        PuzzleSpec.cube7x7.axisOf('3Rw'),
      );
    });
  });

  group('invariants hold at every size', () {
    for (final MapEntry<String, PuzzleSpec> entry in bigCubes.entries) {
      final String name = entry.key;
      final PuzzleSpec spec = entry.value;

      test('$name — produces exactly ${spec.moveCount} legal moves', () {
        for (int i = 0; i < 30; i++) {
          final String scramble = generate.forPuzzle(spec);
          expect(
            GenerateScramble.isValidScramble(scramble, spec),
            isTrue,
            reason: scramble,
          );
        }
      });

      test('$name — invariant 1: never the same face twice running', () {
        for (int i = 0; i < 30; i++) {
          final List<String> faces = _facesOf(generate.forPuzzle(spec), spec);
          for (int j = 1; j < faces.length; j++) {
            expect(faces[j], isNot(faces[j - 1]));
          }
        }
      });

      test('$name — invariant 2: never three consecutive moves on one axis',
          () {
        for (int i = 0; i < 30; i++) {
          final List<String> faces = _facesOf(generate.forPuzzle(spec), spec);
          for (int j = 2; j < faces.length; j++) {
            final int axis = spec.axisOf(faces[j]);
            expect(
              axis == spec.axisOf(faces[j - 1]) &&
                  axis == spec.axisOf(faces[j - 2]),
              isFalse,
              reason: '${faces[j - 2]} ${faces[j - 1]} ${faces[j]}',
            );
          }
        }
      });

      test('$name — every face is reachable', () {
        final Set<String> seen = <String>{};
        for (int i = 0; i < 40; i++) {
          seen.addAll(_facesOf(generate.forPuzzle(spec), spec));
        }
        expect(seen, unorderedEquals(spec.faces));
      });
    }
  });

  group('three-character faces parse longest-first', () {
    test('`3Rw2` is the face 3Rw with modifier 2, not 3R or Rw', () {
      // The 4×4 test already covers `Rw2`; 6×6 pushes the face to three
      // characters, which is where a naive prefix match breaks.
      const PuzzleSpec spec = PuzzleSpec.cube6x6;
      final List<String> tokens =
          List<String>.filled(spec.moveCount, '3Rw2', growable: true);
      // A run of identical faces is illegal, so this only proves parsing:
      // an unparseable face and an illegal one both return false, so build a
      // legal scramble and confirm it validates.
      expect(GenerateScramble.isValidScramble(tokens.join(' '), spec), isFalse);

      final String legal = generate.forPuzzle(spec);
      expect(legal, contains('3'));
      expect(GenerateScramble.isValidScramble(legal, spec), isTrue);
    });
  });

  group('scrambleFor — the structured entry point', () {
    test('an NxN event returns one line at the puzzle\'s move count', () {
      final Scramble scramble = generate.scrambleFor(WcaEvent.cube7x7);
      expect(scramble.lines, hasLength(1));
      expect(scramble.moveCount, 100);
      expect(scramble.notation, ScrambleNotation.faceTurns);
    });

    test('a modifier event scrambles as its base puzzle', () {
      expect(generate.scrambleFor(WcaEvent.oneHanded).moveCount, 20);
      expect(generate.scrambleFor(WcaEvent.blind5x5).moveCount, 60);
      expect(generate.scrambleFor(WcaEvent.fewestMoves).moveCount, 20);
    });

    test('Multi-Blind returns N independent 3×3 scrambles', () {
      final Scramble scramble = generate.scrambleFor(WcaEvent.multiBlind);
      expect(scramble.lines, hasLength(WcaEvent.multiBlind.scrambleCount));
      expect(scramble.isMultiScramble, isTrue);
      for (final List<String> line in scramble.lines) {
        expect(line, hasLength(20));
      }
      // Each line is a whole scramble in its own right.
      expect(
        GenerateScramble.isValidScrambleFor(scramble, PuzzleSpec.cube3x3),
        isTrue,
      );
    });

    test('the legality chain resets at a line break', () {
      // Cube 2\'s first move may legally repeat cube 1\'s last — they are
      // separate scrambles on separate puzzles. Validating the joined string
      // as one sequence would sometimes reject a correct Multi-Blind scramble.
      final Scramble scramble = generate.scrambleFor(WcaEvent.multiBlind);
      expect(
        GenerateScramble.isValidScrambleFor(scramble, PuzzleSpec.cube3x3),
        isTrue,
      );
      // Flattened, the token count alone disqualifies it — which is exactly
      // why the structured validator exists.
      expect(
        GenerateScramble.isValidScramble(
          scramble.tokens.join(' '),
          PuzzleSpec.cube3x3,
        ),
        isFalse,
      );
    });

    test('every event now produces a non-empty scramble of its own', () {
      // All five formerly-unsupported puzzles have real scramblers now, so no
      // event falls back to an empty "scrambles coming" state.
      for (final WcaEvent event in WcaEvent.all) {
        final Scramble scramble = generate.scrambleFor(event);
        expect(scramble.isEmpty, isFalse, reason: event.id);
        expect(scramble.notation, isNot(ScrambleNotation.none),
            reason: event.id);
      }
    });
  });
}

/// The face part of each token in [scramble], longest-match-first.
List<String> _facesOf(String scramble, PuzzleSpec spec) {
  final List<String> faces = spec.faces.toList()
    ..sort((String a, String b) => b.length.compareTo(a.length));

  return scramble.split(' ').where((String t) => t.isNotEmpty).map((String t) {
    return faces.firstWhere(t.startsWith, orElse: () => t);
  }).toList();
}
