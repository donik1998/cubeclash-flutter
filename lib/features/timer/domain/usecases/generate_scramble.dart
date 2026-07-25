import 'dart:math';

import '../entities/puzzle_spec.dart';
import '../entities/scramble.dart';
import '../entities/wca_event.dart';
import 'pyraminx_scrambler.dart';
import 'skewb_scrambler.dart';
import 'square_one_scrambler.dart';

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

  /// Built lazily — each needed only if its puzzle is asked for.
  late final PyraminxScrambler _pyraminx = PyraminxScrambler(random: _random);
  late final SkewbScrambler _skewb = SkewbScrambler(random: _random);
  late final SquareOneScrambler _squareOne =
      SquareOneScrambler(random: _random);

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
  /// **All 17 events now return a real scramble** — the six NxN cubes, the six
  /// modifier events (which reuse their base puzzle), Megaminx and Clock
  /// (pattern), Pyraminx and Skewb (random-state) and Square-1 (random-move).
  /// The [Scramble.empty] path below is therefore unreachable for the current
  /// catalogue; it is kept as graceful degradation so a *future* event shipped
  /// without a scrambler renders the explicit "scrambles coming" card rather
  /// than being handed a 3×3 scramble under its own label — the silent fallback
  /// [call] guards against.
  ///
  /// Multi-Blind returns [WcaEvent.scrambleCount] independent 3×3 scrambles,
  /// one per line, because a Multi-Blind attempt is N scrambles and not one.
  Scramble scrambleFor(WcaEvent event) {
    // Two events scramble on a fixed pattern rather than a puzzle's move set —
    // Megaminx (an alternating R/D drill) and Clock (independent dial states).
    // Both are WCA-legal without a random-*state* solver, unlike the three
    // still-missing puzzles, so they are generated directly here.
    switch (event.family) {
      case PuzzleFamily.dodecahedron:
        return _megaminx();
      case PuzzleFamily.clock:
        return _clock();
      case PuzzleFamily.tetrahedron:
        return _pyraminx.generate();
      case PuzzleFamily.skewb:
        return _skewb.generate();
      case PuzzleFamily.square1:
        return _squareOne.generate();
      default:
        break;
    }

    final PuzzleSpec? spec = event.puzzle;
    if (spec == null) return const Scramble.empty();

    return Scramble(
      lines: <List<String>>[
        for (int i = 0; i < event.scrambleCount; i++) _movesFor(spec),
      ],
      notation: event.notation,
    );
  }

  /// The official WCA Megaminx scramble: seven lines, each ten alternating
  /// `R`/`D` moves (every turn a `++` or `--` big turn) closed by a single
  /// `U` or `U'`. Only the turn directions and the final `U` are random — the
  /// R/D skeleton is fixed, which is exactly why no solver is needed.
  Scramble _megaminx() {
    const int lineCount = 7;
    const int pairsPerLine = 5; // 5 × (R, D) = the ten-move body

    String bigTurn(String face) => '$face${_random.nextBool() ? '++' : '--'}';

    return Scramble(
      lines: <List<String>>[
        for (int line = 0; line < lineCount; line++)
          <String>[
            for (int pair = 0; pair < pairsPerLine; pair++) ...<String>[
              bigTurn('R'),
              bigTurn('D'),
            ],
            _random.nextBool() ? 'U' : "U'",
          ],
      ],
      notation: ScrambleNotation.faceTurns,
    );
  }

  /// The official WCA Clock scramble: nine front dials, a `y2` flip, five back
  /// dials, then the pins left up. Each dial is an independent 0–6 turn in
  /// either direction — no move interacts with another, so a Clock scramble is
  /// just fourteen random dials and a pin state, again needing no solver.
  Scramble _clock() {
    String dial(String pin) {
      final int amount = _random.nextInt(7); // 0–6, WCA range
      return '$pin$amount${_random.nextBool() ? '+' : '-'}';
    }

    return Scramble(
      lines: <List<String>>[
        <String>[
          for (final String pin in _clockFront) dial(pin),
          'y2',
          for (final String pin in _clockBack) dial(pin),
          // The pins left sticking up after the flip — any subset of the four.
          for (final String pin in _clockPins)
            if (_random.nextBool()) pin,
        ],
      ],
      notation: ScrambleNotation.faceTurns,
    );
  }

  static const List<String> _clockFront = <String>[
    'UR',
    'DR',
    'DL',
    'UL',
    'U',
    'R',
    'D',
    'L',
    'ALL',
  ];
  static const List<String> _clockBack = <String>['U', 'R', 'D', 'L', 'ALL'];
  static const List<String> _clockPins = <String>['UR', 'DR', 'DL', 'UL'];

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
