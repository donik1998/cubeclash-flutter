import 'dart:math';

import '../entities/scramble.dart';

/// A Square-1 scrambler.
///
/// **This is a *random-move* scrambler, not (yet) a random-*state* one**, and
/// that distinction is deliberate and documented rather than hidden. Pyraminx
/// and Skewb ship true random-state scramblers because their groups are small
/// enough to solve and to verify by a closure count. Square-1's is not: it
/// shape-shifts, its state space runs to billions, and a WCA-legal random-state
/// scramble needs a genuine two-phase solver (shape reduction, then
/// permutation) that cannot be certified the same way. Shipping that unverified
/// would be exactly the "scramble I can't stand behind" the rest of the app
/// refuses to ship.
///
/// So this does the honest, verifiable thing instead: it walks a long sequence
/// of **legal** Square-1 moves — every slice mechanically valid, tracked
/// through the shape so a corner is never cut — and emits it in real
/// `(top, bottom)/` slash-pairs notation. The result is a genuine, well-mixed
/// Square-1 scramble; it simply is not proven uniform. The uniform random-state
/// two-phase solver is the remaining refinement (roadmap).
///
/// The puzzle is tracked by **shape only** — for each 12-slot layer, where the
/// piece boundaries are — because that is all a legal move needs: a slice is
/// permitted only when the cut at 12 o'clock and 6 o'clock falls on a boundary
/// in both layers rather than through a corner.
class SquareOneScrambler {
  SquareOneScrambler({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const int _slots = 12;

  /// Solved layer boundaries: corners are two slots wide, edges one, so the
  /// ring reads C C E C C E C C E C C E — boundaries at 0,2,3,5,6,8,9,11.
  static const List<bool> _solvedLayer = <bool>[
    true, false, true, true, false, true, //
    true, false, true, true, false, true,
  ];

  /// How many slices a scramble makes before the closing rotation. WCA
  /// Square-1 scrambles run to roughly this many; a dozen-plus slices mixes the
  /// puzzle thoroughly.
  static const int _minSlices = 11;
  static const int _maxSlices = 17;

  Scramble generate() {
    List<bool> top = List<bool>.of(_solvedLayer);
    List<bool> bottom = List<bool>.of(_solvedLayer);

    final int slices =
        _minSlices + _random.nextInt(_maxSlices - _minSlices + 1);
    final List<String> tokens = <String>[];

    for (int i = 0; i < slices; i++) {
      final int u = _pickRotation(top);
      final int d = _pickRotation(bottom);
      top = _rotate(top, u);
      bottom = _rotate(bottom, d);

      tokens.add('(${_normalise(u)},${_normalise(d)})/');

      // Slice: swap the right six slots (0..5) between the two layers.
      final List<bool> newTop = List<bool>.of(top);
      final List<bool> newBottom = List<bool>.of(bottom);
      for (int s = 0; s < 6; s++) {
        newTop[s] = bottom[s];
        newBottom[s] = top[s];
      }
      top = newTop;
      bottom = newBottom;
    }

    // A closing rotation, no trailing slash — as real scrambles are written.
    final int u = _random.nextInt(_slots);
    final int d = _random.nextInt(_slots);
    tokens.add('(${_normalise(u)},${_normalise(d)})');

    return Scramble(
      lines: <List<String>>[tokens],
      notation: ScrambleNotation.slashPairs,
    );
  }

  /// Independently replays a generated [scramble] on a solved puzzle and
  /// returns whether **every** slice it calls for is mechanically legal — the
  /// cut never passing through a corner. Exposed for tests: it re-derives the
  /// shape from the notation alone, so it catches any generator that emits an
  /// illegal move.
  bool isMechanicallyLegal(Scramble scramble) {
    List<bool> top = List<bool>.of(_solvedLayer);
    List<bool> bottom = List<bool>.of(_solvedLayer);

    for (final String token in scramble.tokens) {
      final bool slices = token.endsWith('/');
      final Match? m = RegExp(r'^\((-?\d+),(-?\d+)\)/?$').firstMatch(token);
      if (m == null) return false;
      final int u = int.parse(m.group(1)!);
      final int d = int.parse(m.group(2)!);
      top = _rotate(top, u);
      bottom = _rotate(bottom, d);
      if (!slices) continue;

      if (!(top[0] && top[6] && bottom[0] && bottom[6])) return false;
      final List<bool> newTop = List<bool>.of(top);
      final List<bool> newBottom = List<bool>.of(bottom);
      for (int s = 0; s < 6; s++) {
        newTop[s] = bottom[s];
        newBottom[s] = top[s];
      }
      top = newTop;
      bottom = newBottom;
    }
    return true;
  }

  /// A rotation (in slots) that leaves [layer] sliceable — a boundary at both
  /// 0 and 6 — chosen at random among those that do, so the scramble varies.
  int _pickRotation(List<bool> layer) {
    final List<int> legal = <int>[
      for (int u = 0; u < _slots; u++)
        if (_sliceableAfter(layer, u)) u,
    ];
    // Every reachable Square-1 layer has at least one sliceable rotation.
    return legal[_random.nextInt(legal.length)];
  }

  bool _sliceableAfter(List<bool> layer, int u) {
    // A boundary must sit at slot 0 and slot 6 after rotating by u.
    return layer[(0 - u) % _slots] && layer[(6 - u) % _slots];
  }

  List<bool> _rotate(List<bool> layer, int u) => <bool>[
        for (int i = 0; i < _slots; i++) layer[(i - u) % _slots],
      ];

  /// WCA writes rotations in (-5..6]: a 7-o'clock turn is notated as -5, not 7.
  int _normalise(int u) {
    int v = u % _slots;
    if (v > 6) v -= _slots;
    return v;
  }
}
