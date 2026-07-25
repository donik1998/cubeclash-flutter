import 'dart:math';

import 'package:cubeclash/features/timer/domain/entities/scramble.dart';
import 'package:cubeclash/features/timer/domain/usecases/pyraminx_scrambler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pyraminx random-state scrambler', () {
    test('reachable state count equals the Pyraminx group order', () {
      // The correctness oracle: if a closure over the four moves reaches
      // exactly 933,120 states, the move model *is* a Pyraminx, so anything it
      // generates is a legal Pyraminx state.
      final PyraminxScrambler scrambler = PyraminxScrambler(random: Random(1));
      expect(scrambler.reachableStateCount(), 933120);
    });

    test('the face moves are optimal and irreducible', () {
      // A scramble of N face moves must leave the puzzle exactly N moves from
      // solved — otherwise it is either wrong or reducible, both illegal.
      final PyraminxScrambler scrambler = PyraminxScrambler(random: Random(7));
      for (int i = 0; i < 25; i++) {
        final Scramble scramble = scrambler.generate();
        final List<String> faces = scramble.tokens
            .where((String t) => t.toUpperCase() == t) // U/L/R/B, not tips
            .toList();
        expect(scrambler.faceDistanceOf(faces), faces.length,
            reason: scramble.text);
      }
    });

    test('uses only legal tokens and the faceTurns notation', () {
      final PyraminxScrambler scrambler = PyraminxScrambler(random: Random(3));
      final RegExp token = RegExp(r"^[ULRBulrb]'?$");
      final Scramble scramble = scrambler.generate();

      expect(scramble.notation, ScrambleNotation.faceTurns);
      expect(scramble.lines, hasLength(1));
      for (final String t in scramble.tokens) {
        expect(token.hasMatch(t), isTrue, reason: t);
      }
    });

    test('at most one turn of each of the four tips', () {
      final PyraminxScrambler scrambler = PyraminxScrambler(random: Random(9));
      for (int i = 0; i < 20; i++) {
        final List<String> tips = scrambler
            .generate()
            .tokens
            .where((String t) => t.toLowerCase() == t)
            .toList();
        expect(tips.length, lessThanOrEqualTo(4));
        expect(
            tips.toSet(),
            everyElement(
                isIn(<String>['u', "u'", 'l', "l'", 'r', "r'", 'b', "b'"])));
        // No tip appears twice — each is turned at most once.
        final Set<String> faces =
            tips.map((String t) => t.replaceAll("'", '')).toSet();
        expect(faces.length, tips.length);
      }
    });

    test('is deterministic for a given seed', () {
      final String a = PyraminxScrambler(random: Random(42)).generate().text;
      final String b = PyraminxScrambler(random: Random(42)).generate().text;
      expect(a, b);
    });

    test('successive scrambles differ', () {
      final PyraminxScrambler scrambler = PyraminxScrambler(random: Random(5));
      final Set<String> seen = <String>{
        for (int i = 0; i < 30; i++) scrambler.generate().text,
      };
      expect(seen.length, 30);
    });

    test('face length never exceeds the Pyraminx diameter', () {
      // The non-tip group has diameter 11; no optimal scramble can be longer.
      final PyraminxScrambler scrambler = PyraminxScrambler(random: Random(11));
      for (int i = 0; i < 50; i++) {
        final int faces = scrambler
            .generate()
            .tokens
            .where((String t) => t.toUpperCase() == t)
            .length;
        expect(faces, lessThanOrEqualTo(11));
      }
    });
  });
}
