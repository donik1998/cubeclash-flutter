import 'package:cubeclash/features/timer/domain/entities/penalty.dart';
import 'package:cubeclash/features/timer/domain/usecases/grade_inspection.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCA inspection is all boundaries, so the boundaries are what gets tested.
void main() {
  const GradeInspection grade = GradeInspection();

  group('penalty boundaries', () {
    test('well inside the allowance is clean', () {
      expect(grade(Duration.zero), Penalty.none);
      expect(grade(const Duration(seconds: 8)), Penalty.none);
      expect(
          grade(const Duration(seconds: 14, milliseconds: 999)), Penalty.none);
    });

    test('exactly 15.000 s is still clean', () {
      // Hitting the limit precisely is not an overrun.
      expect(grade(const Duration(seconds: 15)), Penalty.none);
    });

    test('a millisecond past 15 s is +2', () {
      expect(
          grade(const Duration(seconds: 15, milliseconds: 1)), Penalty.plus2);
    });

    test('anywhere in 15–17 s is +2', () {
      expect(grade(const Duration(seconds: 16)), Penalty.plus2);
      expect(
          grade(const Duration(seconds: 16, milliseconds: 999)), Penalty.plus2);
    });

    test('exactly 17.000 s is still only +2', () {
      expect(grade(const Duration(seconds: 17)), Penalty.plus2);
    });

    test('a millisecond past 17 s is a DNF', () {
      expect(grade(const Duration(seconds: 17, milliseconds: 1)), Penalty.dnf);
    });

    test('far past the limit stays a DNF', () {
      expect(grade(const Duration(minutes: 2)), Penalty.dnf);
    });
  });

  group('judge cues', () {
    test('fire at 8 s and 12 s', () {
      expect(
        grade.shouldCue(
          const Duration(milliseconds: 7950),
          const Duration(milliseconds: 8000),
        ),
        isTrue,
      );
      expect(
        grade.shouldCue(
          const Duration(milliseconds: 11950),
          const Duration(milliseconds: 12000),
        ),
        isTrue,
      );
    });

    test('are edge-triggered — a cue does not repeat on later ticks', () {
      expect(
        grade.shouldCue(
          const Duration(milliseconds: 8000),
          const Duration(milliseconds: 8050),
        ),
        isFalse,
      );
      expect(
        grade.shouldCue(
          const Duration(seconds: 9),
          const Duration(seconds: 10),
        ),
        isFalse,
      );
    });

    test('a coarse tick that jumps a cue still fires it exactly once', () {
      // A janky frame must not swallow the 8 s call.
      expect(
        grade.shouldCue(
          const Duration(milliseconds: 7000),
          const Duration(milliseconds: 9000),
        ),
        isTrue,
      );
    });

    test('no cue before the first call', () {
      expect(
        grade.shouldCue(Duration.zero, const Duration(seconds: 1)),
        isFalse,
      );
    });
  });
}
