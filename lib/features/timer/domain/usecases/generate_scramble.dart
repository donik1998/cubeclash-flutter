import 'dart:math';

import '../entities/puzzle_spec.dart';
import '../entities/scramble.dart';
import '../entities/wca_event.dart';

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

  /// A **structured** scramble for [event] — the entry point the app uses.
  ///
  /// Returns [Scramble.empty] rather than throwing for an event with no
  /// scrambler (Megaminx, Pyraminx, Skewb, Square-1, Clock). That is not the
  /// silent fallback [call] guards against — an empty scramble renders as the
  /// explicit "scrambles coming" state, so the user is told there is nothing
  /// rather than handed a 3×3 scramble under a Megaminx label.
  ///
  /// Multi-Blind returns [WcaEvent.scrambleCount] independent 3×3 scrambles,
  /// one per line, because a Multi-Blind attempt is N scrambles and not one.
  Scramble scrambleFor(WcaEvent event) {
    final PuzzleSpec? spec = event.puzzle;
    if (spec == null) return const Scramble.empty();

    return Scramble(
      lines: <List<String>>[
        for (int i = 0; i < event.scrambleCount; i++) _movesFor(spec),
      ],
      notation: event.notation,
    );
  }

  /// A scramble for an explicit [spec].
  String forPuzzle(PuzzleSpec spec) => _movesFor(spec).join(' ');

  /// The move list for [spec] — the shared core of [forPuzzle] and
  /// [scrambleFor].
  List<String> _movesFor(PuzzleSpec spec) {
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

    return moves;
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

  /// The face a token starts with, longest match first, or `null` if it starts
  /// with no known face.
  ///
  /// Longest-first matters on 4×4: `Rw2` must resolve to the face `Rw`, not to
  /// `R` with a nonsense `w2` modifier.
  static String? _faceOf(String token, PuzzleSpec spec) {
    final List<String> faces = spec.faces.toList()
      ..sort((String a, String b) => b.length.compareTo(a.length));

    for (final String face in faces) {
      if (token.startsWith(face)) return face;
    }
    return null;
  }

  /// Validates a structured [scramble] against the same rules.
  ///
  /// **Every line is validated independently**, which is the whole point of
  /// keeping the structure: a Multi-Blind scramble is N separate scrambles, so
  /// the legality chain must reset at each line break rather than treating the
  /// last move of cube 1 as the predecessor of the first move of cube 2.
  static bool isValidScrambleFor(Scramble scramble, PuzzleSpec spec) {
    if (scramble.isEmpty) return false;
    return scramble.lines
        .every((List<String> line) => isValidScramble(line.join(' '), spec));
  }

  /// Validates a single line of scramble against the same rules.
  static bool isValidScramble(String scramble, PuzzleSpec spec) {
    final List<String> tokens =
        scramble.split(' ').where((String t) => t.isNotEmpty).toList();
    if (tokens.length != spec.moveCount) return false;

    String? lastFace;
    String? secondLastFace;

    for (final String token in tokens) {
      // Longest-match, because a face can be more than one character: on 4×4,
      // `Rw2` is the face `Rw` with modifier `2`, not `R` + `w2`.
      final String? face = _faceOf(token, spec);
      if (face == null) return false;

      final String modifier = token.substring(face.length);
      if (!spec.modifiers.contains(modifier)) return false;
      if (!_isLegal(spec, face, lastFace, secondLastFace)) return false;

      secondLastFace = lastFace;
      lastFace = face;
    }
    return true;
  }
}
