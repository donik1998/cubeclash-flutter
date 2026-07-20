import 'package:equatable/equatable.dart';

/// How a scramble for a given event is written down.
///
/// This is the thing that makes `String scramble` insufficient: the notations
/// below do not share a token separator, and for two of them the *layout* is
/// part of the meaning.
enum ScrambleNotation {
  /// `R U2 F' L D` — whitespace-separated face turns. Every NxN cube, plus
  /// Pyraminx, Skewb, Megaminx and Clock, which use different alphabets but
  /// the same separator.
  faceTurns,

  /// `(1,0)/(6,0)/(-3,0)/` — Square-1. Splitting on spaces is meaningless
  /// here; the slash is the separator **and** a move (a slice), so it stays
  /// attached to the token before it and a line may break after it.
  slashPairs,

  /// Multi-Blind: N complete, independent scrambles — one per cube. Each line
  /// is a whole 3×3 scramble, numbered when displayed, and they are never
  /// reflowed into each other.
  multiScramble,

  /// The event has no scrambler yet. Carries no tokens; the UI renders the
  /// "scrambles coming" state instead.
  none,
}

/// A scramble, with its structure intact.
///
/// ## Why this is not a `String`
///
/// Three of the notations above lose information when flattened:
///
///   * **Megaminx** is written as seven lines of eleven moves, and cubers
///     execute it line by line. Reflowing it into a paragraph does not just
///     look different — it makes the scramble materially harder to follow,
///     because losing your place costs you the whole attempt.
///   * **Square-1** is slash-separated. Any renderer that splits on spaces
///     produces one unbreakable 60-character token.
///   * **Multi-Blind** is a list of scrambles, not a scramble.
///
/// So [lines] is the primary structure — a list of lines, each a list of
/// tokens — and every renderer wraps *within* a line and never *across* one.
///
/// ## The wire format stays a string
///
/// [text] joins lines with `\n` and tokens with a single space (except
/// [ScrambleNotation.slashPairs], where the separator is already carried on
/// the token). That is byte-for-byte what TNoodle — the WCA's official
/// scrambling program — emits, and what every existing scramble in the
/// `solves` table already looks like.
///
/// **Decision:** `Solve.scramble`, `POST /solves`, and the `race:scramble`
/// payload all keep carrying a plain string. The backend does not change. The
/// client parses per event on the way in ([Scramble.parse]) and serialises
/// back on the way out ([text]), because notation is a *display* concern and
/// the server has no reason to know about it. The one thing the wire format
/// now guarantees that it did not before is that **`\n` is significant** and
/// must survive the round trip — which JSON gives us for free.
class Scramble extends Equatable {
  const Scramble({required this.lines, required this.notation});

  /// The empty scramble — an event with no scrambler, or a race before GO.
  const Scramble.empty()
      : lines = const <List<String>>[],
        notation = ScrambleNotation.none;

  /// Tokens, grouped by line. Never contains an empty line.
  final List<List<String>> lines;

  final ScrambleNotation notation;

  /// Parses [raw] according to [notation]. Tolerant: blank lines and runs of
  /// whitespace collapse, so a scramble that has been through a text field or
  /// a JSON round trip still parses.
  factory Scramble.parse(String raw, ScrambleNotation notation) {
    if (notation == ScrambleNotation.none || raw.trim().isEmpty) {
      return const Scramble.empty();
    }

    final List<String> rawLines = raw
        .split('\n')
        .map((String l) => l.trim())
        .where((String l) => l.isNotEmpty)
        .toList();

    final List<List<String>> lines = <List<String>>[];
    for (final String line in rawLines) {
      final List<String> tokens = switch (notation) {
        ScrambleNotation.slashPairs => _tokeniseSlashPairs(line),
        _ =>
          line.split(RegExp(r'\s+')).where((String t) => t.isNotEmpty).toList(),
      };
      if (tokens.isNotEmpty) lines.add(tokens);
    }

    return lines.isEmpty
        ? const Scramble.empty()
        : Scramble(lines: lines, notation: notation);
  }

  /// `(1,0)/(6,0)/(-3,0)` → `['(1,0)/', '(6,0)/', '(-3,0)']`.
  ///
  /// The slash stays on the token it follows so a line break lands *after* a
  /// slice, which is where a Square-1 solver would pause anyway. A trailing
  /// slash on the whole scramble is legal notation and is preserved.
  static List<String> _tokeniseSlashPairs(String line) {
    final List<String> tokens = <String>[];
    final StringBuffer current = StringBuffer();

    for (final String char in line.split('')) {
      if (char == ' ') continue;
      current.write(char);
      if (char == '/') {
        tokens.add(current.toString());
        current.clear();
      }
    }
    if (current.isNotEmpty) tokens.add(current.toString());
    return tokens;
  }

  /// The canonical string form — this is what goes over the wire and into the
  /// `solves` table. Round-trips through [Scramble.parse] exactly.
  String get text => lines
      .map((List<String> line) => notation == ScrambleNotation.slashPairs
          ? line.join()
          : line.join(' '))
      .join('\n');

  /// Every token, line structure discarded. For counting and for the
  /// screen-reader label.
  List<String> get tokens =>
      <String>[for (final List<String> line in lines) ...line];

  int get moveCount => tokens.length;

  bool get isEmpty => lines.isEmpty;

  bool get isNotEmpty => lines.isNotEmpty;

  /// True when the scramble is a list of independent scrambles rather than one
  /// sequence — the UI numbers the lines in that case.
  bool get isMultiScramble => notation == ScrambleNotation.multiScramble;

  /// What a screen reader should say. Tokens are comma-separated so `R2` is
  /// read as a move rather than run into the next one, and lines are separated
  /// by a full stop so the reader pauses where the notation does.
  String get semanticsLabel {
    if (isEmpty) return 'No scramble';
    if (isMultiScramble) {
      return <String>[
        for (int i = 0; i < lines.length; i++)
          'Cube ${i + 1}: ${lines[i].join(', ')}',
      ].join('. ');
    }
    return 'Scramble: ${lines.map((List<String> l) => l.join(', ')).join('. ')}';
  }

  @override
  List<Object?> get props => <Object?>[text, notation];

  @override
  String toString() => text;
}
