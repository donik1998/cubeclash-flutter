import 'dart:math';

import 'package:cubeclash/features/timer/domain/entities/scramble.dart';
import 'package:cubeclash/features/timer/domain/usecases/skewb_scrambler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Skewb random-state scrambler', () {
    test('reachable state count equals the Skewb group order', () {
      // The oracle: reach exactly 3,149,280 states and the move model is a
      // faithful Skewb, so everything it produces is a legal Skewb state.
      final SkewbScrambler scrambler = SkewbScrambler(random: Random(1));
      expect(scrambler.reachableStateCount(), 3149280);
    });

    test('the bidirectional solver actually solves', () {
      final SkewbScrambler scrambler = SkewbScrambler(random: Random(7));
      for (int i = 0; i < 20; i++) {
        final List<String> tokens = scrambler.generate().tokens;
        expect(scrambler.solvesCleanly(tokens), isTrue);
      }
    });

    test('scrambles are irreducible and self-consistent', () {
      final SkewbScrambler scrambler = SkewbScrambler(random: Random(13));
      for (int i = 0; i < 20; i++) {
        final List<String> tokens = scrambler.generate().tokens;

        // No two adjacent moves are about the same corner — that would collapse
        // into one, making the scramble shorter than it looks.
        for (int j = 1; j < tokens.length; j++) {
          expect(tokens[j][0], isNot(tokens[j - 1][0]),
              reason: tokens.join(' '));
        }

        // Applying the scramble and re-solving reproduces its own length — proof
        // the inversion is consistent and nothing cancels.
        expect(scrambler.optimalSolveMovesAfter(tokens), tokens.length,
            reason: tokens.join(' '));
      }
    });

    test('uses only legal tokens and the faceTurns notation', () {
      final SkewbScrambler scrambler = SkewbScrambler(random: Random(3));
      final RegExp token = RegExp(r"^[ULRB]'?$");
      final Scramble scramble = scrambler.generate();

      expect(scramble.notation, ScrambleNotation.faceTurns);
      expect(scramble.lines, hasLength(1));
      expect(scramble.tokens, isNotEmpty);
      for (final String t in scramble.tokens) {
        expect(token.hasMatch(t), isTrue, reason: t);
      }
    });

    test('every scramble is a bounded, non-trivial length', () {
      // Optimal solutions in this move model run to ~10 moves — in the same
      // 8–11 range TNoodle emits for Skewb — and are never empty.
      final SkewbScrambler scrambler = SkewbScrambler(random: Random(11));
      for (int i = 0; i < 40; i++) {
        final int length = scrambler.generate().tokens.length;
        expect(length, inInclusiveRange(1, 11));
      }
    });

    test('is deterministic for a given seed', () {
      final String a = SkewbScrambler(random: Random(42)).generate().text;
      final String b = SkewbScrambler(random: Random(42)).generate().text;
      expect(a, b);
    });

    test('successive scrambles differ', () {
      final SkewbScrambler scrambler = SkewbScrambler(random: Random(5));
      final Set<String> seen = <String>{
        for (int i = 0; i < 25; i++) scrambler.generate().text,
      };
      expect(seen.length, greaterThan(20));
    });
  });
}
