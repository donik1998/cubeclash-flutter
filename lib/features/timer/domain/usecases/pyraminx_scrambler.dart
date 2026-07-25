import 'dart:math';
import 'dart:typed_data';

import '../entities/scramble.dart';

/// A **random-state** Pyraminx scrambler.
///
/// A random-*move* scramble is not WCA-legal: it neither samples states
/// uniformly nor guarantees a non-reducible sequence. So this builds a uniform
/// random reachable state and solves it optimally, then hands back the inverse
/// of that solution — a genuine random-state scramble.
///
/// ## Why this is verifiable
///
/// The Pyraminx group (ignoring the four trivial tips) has exactly **933,120**
/// states. A breadth-first closure over the four face moves defined here
/// reaches that many and no more — see [reachableStateCount], asserted in the
/// tests. Matching the known group order is strong evidence the move model is a
/// faithful Pyraminx rather than some other permutation puzzle, which is what
/// makes "legal" a claim and not a hope. The four tips are then scrambled
/// independently, exactly as a physical Pyraminx and TNoodle both treat them.
class PyraminxScrambler {
  PyraminxScrambler({Random? random}) : _random = random ?? Random();

  final Random _random;

  // --- Piece model -----------------------------------------------------------
  //
  // 4 axial corners (one per vertex U, L, R, B), each with orientation 0..2 and
  // a fixed position. 6 edges (UL UR UB LR LB RB) with a permutation and a
  // 2-state orientation. Tips are not part of the solved group — they are added
  // at the end.

  static const int _edgeCount = 6;
  static const int _cornerCount = 4;

  /// Each move: the corner it twists, and the new contents of its three edge
  /// slots as `(destSlot, srcSlot, orientationAdd)`. A 120° turn; a 240° turn
  /// applies it twice. Verified by [reachableStateCount].
  static const List<_Move> _moves = <_Move>[
    // U twists corner 0 and cycles edges UL(0) UR(1) UB(2).
    _Move(0, <List<int>>[
      <int>[0, 2, 1],
      <int>[1, 0, 1],
      <int>[2, 1, 0],
    ]),
    // L twists corner 1 and cycles edges UL(0) LR(3) LB(4).
    _Move(1, <List<int>>[
      <int>[0, 4, 1],
      <int>[4, 3, 1],
      <int>[3, 0, 0],
    ]),
    // R twists corner 2 and cycles edges UR(1) LR(3) RB(5).
    _Move(2, <List<int>>[
      <int>[1, 5, 1],
      <int>[5, 3, 1],
      <int>[3, 1, 0],
    ]),
    // B twists corner 3 and cycles edges UB(2) LB(4) RB(5).
    _Move(3, <List<int>>[
      <int>[2, 5, 1],
      <int>[5, 4, 1],
      <int>[4, 2, 0],
    ]),
  ];

  static const List<String> _faceNames = <String>['U', 'L', 'R', 'B'];
  static const List<String> _tipNames = <String>['u', 'l', 'r', 'b'];

  // --- State encoding --------------------------------------------------------
  //
  // A state is (cornerOri[4], edgePerm[6], edgeOri[6]) packed into one int:
  //   ((cornerRank * 720) + permRank) * 64 + oriMask
  // The ranges are not minimal (720 vs 360 even perms, 64 vs 32 even masks), but
  // uniqueness is all the closure and the table need.
  static const int _permCount = 720; // 6!
  static const int _encodingSize = 81 * _permCount * 64;

  int _encode(List<int> cornerOri, List<int> edgePerm, List<int> edgeOri) {
    int cornerRank = 0;
    for (int i = 0; i < _cornerCount; i++) {
      cornerRank = cornerRank * 3 + cornerOri[i];
    }
    int oriMask = 0;
    for (int i = 0; i < _edgeCount; i++) {
      oriMask |= edgeOri[i] << i;
    }
    return (cornerRank * _permCount + _permRank(edgePerm)) * 64 + oriMask;
  }

  // --- Move application ------------------------------------------------------

  _State _apply(_State s, int face, int times) {
    final List<int> corner = List<int>.of(s.cornerOri);
    List<int> perm = List<int>.of(s.edgePerm);
    List<int> ori = List<int>.of(s.edgeOri);
    final _Move move = _moves[face];

    for (int t = 0; t < times; t++) {
      corner[move.corner] = (corner[move.corner] + 1) % 3;
      final List<int> newPerm = List<int>.of(perm);
      final List<int> newOri = List<int>.of(ori);
      for (final List<int> step in move.edgeCycle) {
        final int dest = step[0];
        final int src = step[1];
        final int add = step[2];
        newPerm[dest] = perm[src];
        newOri[dest] = (ori[src] + add) & 1;
      }
      perm = newPerm;
      ori = newOri;
    }
    return _State(corner, perm, ori);
  }

  _State get _solved => _State(
        List<int>.filled(_cornerCount, 0),
        List<int>.generate(_edgeCount, (int i) => i),
        List<int>.filled(_edgeCount, 0),
      );

  // --- Solver ----------------------------------------------------------------
  //
  // A breadth-first distance table from solved: one byte per reachable state,
  // built once and cached. Solving any state is then a hill-descent down the
  // gradient — every step to a strictly-closer neighbour — which is optimal.

  static Uint8List? _distance;

  Uint8List _distanceTable() {
    final Uint8List? cached = _distance;
    if (cached != null) return cached;

    final Uint8List dist = Uint8List(_encodingSize)
      ..fillRange(0, _encodingSize, 255);
    final _State solved = _solved;
    final int start =
        _encode(solved.cornerOri, solved.edgePerm, solved.edgeOri);
    dist[start] = 0;

    List<_State> frontier = <_State>[solved];
    int depth = 0;
    while (frontier.isNotEmpty) {
      final List<_State> next = <_State>[];
      for (final _State state in frontier) {
        for (int face = 0; face < _moves.length; face++) {
          for (int times = 1; times <= 2; times++) {
            final _State n = _apply(state, face, times);
            final int code = _encode(n.cornerOri, n.edgePerm, n.edgeOri);
            if (dist[code] == 255) {
              dist[code] = depth + 1;
              next.add(n);
            }
          }
        }
      }
      frontier = next;
      depth++;
    }

    return _distance = dist;
  }

  /// Applies the face moves in [tokens] (tips ignored) to a solved puzzle and
  /// returns the resulting state's optimal distance from solved. Exposed for
  /// tests: a well-formed scramble's face portion of length N must leave the
  /// puzzle exactly N moves from solved — proof it is both correct and
  /// irreducible.
  int faceDistanceOf(List<String> tokens) {
    _State state = _solved;
    for (final String token in tokens) {
      final int face = _faceNames.indexOf(token.replaceAll("'", ''));
      if (face == -1) continue; // a tip, or noise — not a face move
      state = _apply(state, face, token.endsWith("'") ? 2 : 1);
    }
    return _distanceTable()[
        _encode(state.cornerOri, state.edgePerm, state.edgeOri)];
  }

  /// The number of states a closure over the four moves reaches — the
  /// correctness oracle. Must be 933,120 for a faithful Pyraminx.
  int reachableStateCount() {
    final Uint8List dist = _distanceTable();
    int count = 0;
    for (int i = 0; i < dist.length; i++) {
      if (dist[i] != 255) count++;
    }
    return count;
  }

  /// The optimal solution of [state] as a list of `(face, times)` moves, found
  /// by descending the distance gradient.
  List<List<int>> _solve(_State state) {
    final Uint8List dist = _distanceTable();
    final List<List<int>> solution = <List<int>>[];
    _State current = state;
    int here =
        dist[_encode(current.cornerOri, current.edgePerm, current.edgeOri)];

    while (here > 0) {
      bool stepped = false;
      for (int face = 0; face < _moves.length && !stepped; face++) {
        for (int times = 1; times <= 2; times++) {
          final _State n = _apply(current, face, times);
          final int d = dist[_encode(n.cornerOri, n.edgePerm, n.edgeOri)];
          if (d == here - 1) {
            solution.add(<int>[face, times]);
            current = n;
            here = d;
            stepped = true;
            break;
          }
        }
      }
    }
    return solution;
  }

  // --- Scramble generation ---------------------------------------------------

  /// A random-state Pyraminx scramble: `L R' U L' R B U' l r' b`-style.
  Scramble generate() {
    final _State state = _randomState();
    final List<List<int>> solution = _solve(state);

    // The scramble is the inverse of the solution: reversed, each turn negated.
    final List<String> tokens = <String>[
      for (final List<int> move in solution.reversed)
        _faceToken(move[0], 3 - move[1]),
    ];

    // Tips are independent: each of the four gets a random 0/1/2 turn.
    for (int tip = 0; tip < 4; tip++) {
      final int times = _random.nextInt(3);
      if (times != 0) tokens.add(_tipToken(tip, times));
    }

    return Scramble(
      lines: <List<String>>[tokens],
      notation: ScrambleNotation.faceTurns,
    );
  }

  _State _randomState() {
    // Uniform over the reachable group: any corner orientations, an even edge
    // permutation, and an even-parity edge orientation.
    final List<int> corner =
        List<int>.generate(_cornerCount, (_) => _random.nextInt(3));

    final List<int> perm = List<int>.generate(_edgeCount, (int i) => i);
    for (int i = _edgeCount - 1; i > 0; i--) {
      final int j = _random.nextInt(i + 1);
      final int tmp = perm[i];
      perm[i] = perm[j];
      perm[j] = tmp;
    }
    if (_parity(perm) != 0) {
      final int tmp = perm[0];
      perm[0] = perm[1];
      perm[1] = tmp;
    }

    final List<int> ori =
        List<int>.generate(_edgeCount, (_) => _random.nextInt(2));
    final int sum = ori.fold(0, (int a, int b) => a + b);
    if (sum.isOdd) ori[0] ^= 1;

    return _State(corner, perm, ori);
  }

  String _faceToken(int face, int times) =>
      times == 1 ? _faceNames[face] : "${_faceNames[face]}'";

  String _tipToken(int tip, int times) =>
      times == 1 ? _tipNames[tip] : "${_tipNames[tip]}'";

  // --- Permutation ranking ---------------------------------------------------

  static int _permRank(List<int> perm) {
    final List<int> elems = List<int>.of(perm);
    int rank = 0;
    int factorial = 1;
    for (int i = 2; i <= _edgeCount; i++) {
      factorial *= i;
    }
    for (int i = 0; i < _edgeCount; i++) {
      factorial ~/= (_edgeCount - i);
      int smaller = 0;
      for (int j = i + 1; j < _edgeCount; j++) {
        if (elems[j] < elems[i]) smaller++;
      }
      rank += smaller * factorial;
    }
    return rank;
  }

  static int _parity(List<int> perm) {
    int inversions = 0;
    for (int i = 0; i < perm.length; i++) {
      for (int j = i + 1; j < perm.length; j++) {
        if (perm[i] > perm[j]) inversions++;
      }
    }
    return inversions & 1;
  }
}

/// One face move: the corner it twists and the new content of each edge slot.
class _Move {
  const _Move(this.corner, this.edgeCycle);

  final int corner;

  /// `[destSlot, srcSlot, orientationAdd]` triples.
  final List<List<int>> edgeCycle;
}

class _State {
  _State(this.cornerOri, this.edgePerm, this.edgeOri);

  final List<int> cornerOri;
  final List<int> edgePerm;
  final List<int> edgeOri;
}
