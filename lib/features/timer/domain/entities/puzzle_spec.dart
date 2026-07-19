/// Describes a puzzle well enough to scramble it.
///
/// Pure data, pure Dart. Adding 2×2 or 4×4 later means adding a constant here,
/// not touching the generator — the move-legality rules are identical for every
/// NxN cube; only the face set, turn depth and move count differ.
class PuzzleSpec {
  const PuzzleSpec({
    required this.event,
    required this.axes,
    required this.moveCount,
    this.modifiers = const <String>['', "'", '2'],
  });

  /// Event id as it goes over the wire (`3x3`, `2x2`, …).
  final String event;

  /// Faces grouped by the axis they turn about.
  ///
  /// Grouping is what makes the redundancy rules expressible: two faces on the
  /// same axis commute (`R` and `L` do not interfere), which is exactly why a
  /// third consecutive move on one axis is always reducible.
  final List<List<String>> axes;

  /// How many moves a scramble contains. 20 for 3×3 — long enough that the
  /// state is effectively random under a random-move scrambler.
  final int moveCount;

  /// Turn modifiers appended to a face: quarter turn, inverse, half turn.
  final List<String> modifiers;

  /// Flat list of every face, in axis order.
  List<String> get faces =>
      <String>[for (final List<String> axis in axes) ...axis];

  /// Index of the axis [face] belongs to, or -1 if it isn't part of this
  /// puzzle.
  int axisOf(String face) {
    for (int i = 0; i < axes.length; i++) {
      if (axes[i].contains(face)) return i;
    }
    return -1;
  }

  /// The 3×3 cube — the only MVP event (docs → Concept & Scope: "WCA scrambles
  /// — 3x3 to start; code structured to add events later").
  static const PuzzleSpec cube3x3 = PuzzleSpec(
    event: '3x3',
    axes: <List<String>>[
      <String>['U', 'D'],
      <String>['L', 'R'],
      <String>['F', 'B'],
    ],
    moveCount: 20,
  );

  /// 2×2 — same faces, fewer moves. Not surfaced in the MVP event picker yet,
  /// but proves the generator is puzzle-agnostic.
  static const PuzzleSpec cube2x2 = PuzzleSpec(
    event: '2x2',
    axes: <List<String>>[
      <String>['U', 'D'],
      <String>['L', 'R'],
      <String>['F', 'B'],
    ],
    moveCount: 11,
  );

  /// Every puzzle the scrambler can currently produce, by event id.
  static const Map<String, PuzzleSpec> byEvent = <String, PuzzleSpec>{
    '3x3': cube3x3,
    '2x2': cube2x2,
  };
}
