/// Where a scramble came from.
///
/// Mirrors the `scramble_source` enum on the `solves` table (docs → Data
/// Model) and the segmented control at the top of the scramble card in Figma
/// (`Timer Home` → `scramble` → `scrtabs`).
enum ScrambleSource {
  /// Generated locally by the random-move scrambler. The MVP default.
  random,

  /// A scramble from a real WCA competition round. Roadmap: needs the
  /// competition dataset behind it.
  wca,

  /// Re-solve the last scramble — the standard way to compare two attempts at
  /// the same case, or to let a friend try yours.
  reused;

  /// Wire value for `POST /solves { scramble_source }`.
  String get wire => switch (this) {
        ScrambleSource.random => 'random',
        ScrambleSource.wca => 'wca',
        ScrambleSource.reused => 'reused',
      };

  /// Segment label, matching the Figma frame exactly.
  String get label => switch (this) {
        ScrambleSource.random => 'Random',
        ScrambleSource.wca => 'WCA comps',
        ScrambleSource.reused => 'Last used',
      };

  /// The caption under the scramble.
  String get caption => switch (this) {
        ScrambleSource.random => 'Random scramble',
        ScrambleSource.wca => 'From a WCA round',
        ScrambleSource.reused => 'Your last scramble',
      };

  /// Only `random` is generated locally; the other two are roadmap and render
  /// as unavailable rather than silently falling back (docs → Concept & Scope
  /// puts full WCA random-state scrambles on the roadmap).
  bool get isAvailable => this == ScrambleSource.random;

  static ScrambleSource fromWire(String? wire) => switch (wire) {
        'wca' => ScrambleSource.wca,
        'reused' => ScrambleSource.reused,
        _ => ScrambleSource.random,
      };
}
