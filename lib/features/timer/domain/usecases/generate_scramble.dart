import 'dart:math';

import '../entities/puzzle_spec.dart';

/// Generates a random-move scramble.
///
/// Pure Dart, computed **locally** — the client does not call `GET /scramble`
/// for solo solves. A scramble is not competitive truth, so there is nothing to
/// gain from a round trip and a lot to lose: the timer must work offline and
/// must never make the user wait to start solving. (Race scrambles are the
/// opposite case — those come from the server so both players get the same one.)
///
/// ## Why the redundancy rules matter
///
/// A naive "pick 20 random moves" scrambler produces sequences that are shorter
/// than they look, because adjacent moves collapse:
///
///   * **Same face twice** — `R R'` cancels to nothing, `R R` reduces to `R2`.
///     Every such pair costs a move of real scrambling.
///   * **Three consecutive moves on one axis** — `R L R` is reducible. Opposite
///     faces commute (`R L == L R`), so `R L R == R R L == R2 L`. Because an
///     axis has only two faces, *any* third move on the same axis must repeat
///     one of the previous two and therefore collapses.
///
/// So the generator rejects a candidate face when either holds. This is the
/// standard random-move approach; genuine WCA scrambles use a random-*state*
/// two-phase solver, which is roadmap (docs → Concept & Scope).
///
/// [random] is injectable so tests can seed it and assert on exact output.
class GenerateScramble {
  GenerateScramble({Random? random}) : _random = random ?? _sharedRandom;

  final Random _random;

  static final Random _sharedRandom = Random();

  /// A scramble for [event], e.g. `"R U2 F' L D R2 …"`.
  ///
  /// Throws [ArgumentError] for an event the scrambler doesn't know — better a
  /// loud failure than silently handing the user a 3×3 scramble for a 4×4.
  String call([String event = '3x3']) {
    final PuzzleSpec? spec = PuzzleSpec.byEvent[event];
    if (spec == null) {
      throw ArgumentError.value(event, 'event', 'No scrambler for this event');
    }
    return forPuzzle(spec);
  }

  /// A scramble for an explicit [spec].
  String forPuzzle(PuzzleSpec spec) {
    final List<String> faces = spec.faces;
    final List<String> moves = <String>[];

    // The only history the legality rules need.
    String? lastFace;
    String? secondLastFace;

    while (moves.length < spec.moveCount) {
      final String face = faces[_random.nextInt(faces.length)];
      if (!_isLegal(spec, face, lastFace, secondLastFace)) continue;

      final String modifier =
          spec.modifiers[_random.nextInt(spec.modifiers.length)];
      moves.add('$face$modifier');

      secondLastFace = lastFace;
      lastFace = face;
    }

    return moves.join(' ');
  }

  /// Whether [face] may follow [lastFace] / [secondLastFace].
  ///
  /// Kept static and separate so the invariants are directly unit-testable
  /// rather than only observable through generated output.
  static bool _isLegal(
    PuzzleSpec spec,
    String face,
    String? lastFace,
    String? secondLastFace,
  ) {
    if (lastFace == null) return true;

    // Rule 1 — never the same face twice running (`R R'`).
    if (face == lastFace) return false;

    if (secondLastFace == null) return true;

    // Rule 2 — never a third consecutive move on one axis (`R L R`).
    final int axis = spec.axisOf(face);
    return !(axis == spec.axisOf(lastFace) &&
        axis == spec.axisOf(secondLastFace));
  }

  /// Public mirror of the legality rules, for tests and for any future
  /// scramble *validator* (e.g. sanity-checking a scramble the server sent).
  static bool isLegalMove(
    PuzzleSpec spec,
    String face, {
    String? lastFace,
    String? secondLastFace,
  }) =>
      _isLegal(spec, face, lastFace, secondLastFace);

  /// Validates a whole scramble string against the same rules.
  static bool isValidScramble(String scramble, PuzzleSpec spec) {
    final List<String> tokens =
        scramble.split(' ').where((String t) => t.isNotEmpty).toList();
    if (tokens.length != spec.moveCount) return false;

    String? lastFace;
    String? secondLastFace;

    for (final String token in tokens) {
      final String face = token[0];
      final String modifier = token.substring(1);
      if (spec.axisOf(face) == -1) return false;
      if (!spec.modifiers.contains(modifier)) return false;
      if (!_isLegal(spec, face, lastFace, secondLastFace)) return false;

      secondLastFace = lastFace;
      lastFace = face;
    }
    return true;
  }
}
