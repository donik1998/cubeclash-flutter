import 'dart:math';

import 'package:cubeclash/features/timer/domain/entities/scramble.dart';
import 'package:cubeclash/features/timer/domain/usecases/square_one_scrambler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Square-1 random-move scrambler', () {
    test('every slice it emits is mechanically legal', () {
      final SquareOneScrambler scrambler =
          SquareOneScrambler(random: Random(1));
      for (int i = 0; i < 200; i++) {
        expect(scrambler.isMechanicallyLegal(scrambler.generate()), isTrue);
      }
    });

    test('is written in slash-pairs notation that round-trips', () {
      final SquareOneScrambler scrambler =
          SquareOneScrambler(random: Random(2));
      final Scramble scramble = scrambler.generate();

      expect(scramble.notation, ScrambleNotation.slashPairs);
      expect(scramble.lines, hasLength(1));
      // The canonical text re-parses to the same tokens.
      final Scramble reparsed =
          Scramble.parse(scramble.text, ScrambleNotation.slashPairs);
      expect(reparsed.lines, scramble.lines);
    });

    test('every token is a well-formed (top,bottom) pair', () {
      final SquareOneScrambler scrambler =
          SquareOneScrambler(random: Random(3));
      final RegExp pair = RegExp(r'^\((-?[0-6]),(-?[0-6])\)/?$');
      for (final String token in scrambler.generate().tokens) {
        expect(pair.hasMatch(token), isTrue, reason: token);
      }
    });

    test('rotations are normalised into the WCA range (-5..6)', () {
      final SquareOneScrambler scrambler =
          SquareOneScrambler(random: Random(4));
      final RegExp pair = RegExp(r'^\((-?\d+),(-?\d+)\)/?$');
      for (int i = 0; i < 50; i++) {
        for (final String token in scrambler.generate().tokens) {
          final Match m = pair.firstMatch(token)!;
          for (final String g in <String>[m.group(1)!, m.group(2)!]) {
            final int v = int.parse(g);
            expect(v, inInclusiveRange(-5, 6));
          }
        }
      }
    });

    test('only the final token lacks a trailing slash', () {
      final List<String> tokens =
          SquareOneScrambler(random: Random(5)).generate().tokens;
      expect(tokens.length, greaterThan(2));
      for (int i = 0; i < tokens.length - 1; i++) {
        expect(tokens[i].endsWith('/'), isTrue, reason: tokens[i]);
      }
      expect(tokens.last.endsWith('/'), isFalse);
    });

    test('is deterministic for a given seed, and varies across scrambles', () {
      expect(
        SquareOneScrambler(random: Random(9)).generate().text,
        SquareOneScrambler(random: Random(9)).generate().text,
      );
      final SquareOneScrambler scrambler =
          SquareOneScrambler(random: Random(9));
      final Set<String> seen = <String>{
        for (int i = 0; i < 30; i++) scrambler.generate().text,
      };
      expect(seen.length, greaterThan(25));
    });
  });
}
