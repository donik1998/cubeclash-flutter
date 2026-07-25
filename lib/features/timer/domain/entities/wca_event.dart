import 'event_format.dart';
import 'puzzle_spec.dart';
import 'scramble.dart';
import 'solve_result.dart';

/// The physical shape an event is solved on.
///
/// Pure domain — deliberately **not** `PuzzleShape` from `core/widgets`, which
/// is a Flutter type. The presentation layer maps one onto the other; the
/// domain must stay importable by a plain Dart test.
enum PuzzleFamily {
  /// An NxN cube. Paired with [WcaEvent.cubeSize].
  cube,
  dodecahedron,
  tetrahedron,

  /// Skewb — a corner-turning cube. Drawn as a cube face cut on the diagonal.
  skewb,

  /// Square-1 — a shape-shifter. Drawn as its off-centre bisected square.
  square1,

  /// Clock — not a twisty puzzle at all.
  clock,
}

/// A discipline applied to a puzzle, rather than a different puzzle.
///
/// **The icon decision the prompt asks for.** Seventeen bespoke icons is the
/// wrong answer, because seventeen events are not seventeen puzzles — they are
/// eleven puzzles and five disciplines. `3BLD` *is* a 3×3; One-Handed *is* a
/// 3×3. Cubers name the events that way, so the icon composes the same way: a
/// base [PuzzleFamily] shape, plus a small modifier badge in the bottom-right
/// corner. Adding an eighteenth event is then a row in a table, not a new
/// vector file, and a 4×4 and a 4BLD are recognisably the same puzzle at a
/// glance — which is the actual job of the icon in a picker.
enum PuzzleModifier {
  none,
  blindfolded,
  oneHanded,
  fewestMoves,
  multiBlind;

  /// Suffix appended to the base puzzle's name.
  String? get suffix => switch (this) {
        PuzzleModifier.none => null,
        PuzzleModifier.blindfolded => 'Blindfolded',
        PuzzleModifier.oneHanded => 'One-Handed',
        PuzzleModifier.fewestMoves => 'Fewest Moves',
        PuzzleModifier.multiBlind => 'Multi-Blind',
      };
}

/// How the event picker groups the seventeen.
///
/// A seventeen-item flat list is not a picker. Four groups, in the order a
/// cuber would look for them.
enum EventGroup {
  nxn('Cubes'),
  otherPuzzles('Other puzzles'),
  blindfolded('Blindfolded'),
  special('Special');

  const EventGroup(this.label);

  final String label;
}

/// One official WCA event.
///
/// All seventeen, per **WCA Regulations §9b** (verified July 2026 — see
/// [EventFormat] for the regulation numbers and for the two places
/// `PROMPT_WCA_EVENTS.md` differed from them).
///
/// Constructed as constants rather than an enum because an event carries a
/// [PuzzleSpec], and enum members cannot hold one without the registry
/// becoming circular.
class WcaEvent {
  const WcaEvent({
    required this.id,
    required this.name,
    required this.shortName,
    required this.family,
    required this.format,
    required this.group,
    this.cubeSize,
    this.modifier = PuzzleModifier.none,
    this.puzzle,
    this.notation = ScrambleNotation.faceTurns,
    this.resultKind = ResultKind.time,
    this.scrambleCount = 1,
    this.attemptLimit,
    this.isRaceable = false,
    this.isQuickMatch = false,
  });

  /// Wire id, as it goes to `POST /solves { event }` and
  /// `GET /leaderboard?event=`.
  ///
  /// **These extend the ids already in the database** (`3x3`, `4x4`) rather
  /// than switching to the WCA's own `333`/`444` codes. Existing solves stay
  /// valid, and the ids stay readable in a log. New ids follow the same shape:
  /// the puzzle, then the discipline — `3x3-oh`, `4x4-bld`, `3x3-fmc`.
  final String id;

  /// Full name for the picker and the session header.
  final String name;

  /// How cubers write it — `3BLD`, `OH`, `FMC`. Used where space is tight.
  final String shortName;

  final PuzzleFamily family;

  /// N, for [PuzzleFamily.cube]. Drives the icon's grid density.
  final int? cubeSize;

  final PuzzleModifier modifier;

  /// Competition format (Regulation 9b).
  final EventFormat format;

  final EventGroup group;

  /// The puzzle this event is scrambled on, or `null` if no scrambler exists
  /// for it yet. See [hasScrambler].
  final PuzzleSpec? puzzle;

  final ScrambleNotation notation;

  final ResultKind resultKind;

  /// How many independent scrambles one attempt needs. Only Multi-Blind is
  /// ever above 1.
  final int scrambleCount;

  /// The WCA time limit for a single attempt, where one is inherent to the
  /// event rather than set per round: one hour for Fewest Moves (Regulation
  /// E2) and for Multi-Blind (Regulation H1b, capped at 60 minutes).
  final Duration? attemptLimit;

  /// Whether this event can be raced at all — see [raceableEvents].
  final bool isRaceable;

  /// Whether quick match will search for it. Stricter than [isRaceable].
  final bool isQuickMatch;

  /// Whether the app can generate a legal scramble for this event today.
  ///
  /// True for **every** event now: the twelve puzzle-backed events (a [puzzle]
  /// set), plus **Megaminx and Clock** (a fixed pattern of independent turns,
  /// WCA-legal with no solver), plus **Pyraminx and Skewb** (genuine
  /// random-*state* scramblers, solved directly), plus **Square-1** (a legal
  /// random-*move* scrambler — the one exception; its uniform random-state
  /// two-phase solver is the remaining roadmap refinement). See
  /// [_bespokeScramblerFamilies] and `GenerateScramble.scrambleFor`.
  ///
  /// Kept as a gate rather than hard-coded `true`, because `WcaEvent.fromId` is
  /// lenient and the app should still degrade gracefully if a future event ever
  /// ships without a scrambler.
  bool get hasScrambler =>
      puzzle != null || _bespokeScramblerFamilies.contains(family);

  /// Families with a bespoke scrambler that needs no [PuzzleSpec]: Megaminx and
  /// Clock (pattern), Pyraminx and Skewb (random-state), Square-1 (random-move).
  static const Set<PuzzleFamily> _bespokeScramblerFamilies = <PuzzleFamily>{
    PuzzleFamily.dodecahedron,
    PuzzleFamily.clock,
    PuzzleFamily.tetrahedron,
    PuzzleFamily.skewb,
    PuzzleFamily.square1,
  };

  /// Whether the result is entered by hand rather than measured by the timer.
  ///
  /// Fewest Moves is the only event where the timer interaction is simply
  /// wrong: you are not racing a clock, you are writing down a solution, so
  /// the screen offers a move-count field instead of a touch surface.
  bool get isManualEntry => resultKind == ResultKind.moveCount;

  /// Whether the event runs long enough that the "one solve, ten seconds"
  /// assumptions elsewhere in the app stop holding.
  bool get isLongForm =>
      resultKind == ResultKind.multiBlind ||
      resultKind == ResultKind.moveCount ||
      cubeSize != null && cubeSize! >= 6;

  // --- The seventeen ---------------------------------------------------------

  static const WcaEvent cube2x2 = WcaEvent(
    id: '2x2',
    name: '2×2 Cube',
    shortName: '2×2',
    family: PuzzleFamily.cube,
    cubeSize: 2,
    format: EventFormat.ao5,
    group: EventGroup.nxn,
    puzzle: PuzzleSpec.cube2x2,
    isRaceable: true,
    isQuickMatch: true,
  );

  static const WcaEvent cube3x3 = WcaEvent(
    id: '3x3',
    name: '3×3 Cube',
    shortName: '3×3',
    family: PuzzleFamily.cube,
    cubeSize: 3,
    format: EventFormat.ao5,
    group: EventGroup.nxn,
    puzzle: PuzzleSpec.cube3x3,
    isRaceable: true,
    isQuickMatch: true,
  );

  static const WcaEvent cube4x4 = WcaEvent(
    id: '4x4',
    name: '4×4 Cube',
    shortName: '4×4',
    family: PuzzleFamily.cube,
    cubeSize: 4,
    format: EventFormat.ao5,
    group: EventGroup.nxn,
    puzzle: PuzzleSpec.cube4x4,
    isRaceable: true,
  );

  static const WcaEvent cube5x5 = WcaEvent(
    id: '5x5',
    name: '5×5 Cube',
    shortName: '5×5',
    family: PuzzleFamily.cube,
    cubeSize: 5,
    format: EventFormat.ao5,
    group: EventGroup.nxn,
    puzzle: PuzzleSpec.cube5x5,
    isRaceable: true,
  );

  static const WcaEvent cube6x6 = WcaEvent(
    id: '6x6',
    name: '6×6 Cube',
    shortName: '6×6',
    family: PuzzleFamily.cube,
    cubeSize: 6,
    // Regulation 9b2a.
    format: EventFormat.mo3,
    group: EventGroup.nxn,
    puzzle: PuzzleSpec.cube6x6,
    isRaceable: true,
  );

  static const WcaEvent cube7x7 = WcaEvent(
    id: '7x7',
    name: '7×7 Cube',
    shortName: '7×7',
    family: PuzzleFamily.cube,
    cubeSize: 7,
    format: EventFormat.mo3,
    group: EventGroup.nxn,
    puzzle: PuzzleSpec.cube7x7,
    isRaceable: true,
  );

  static const WcaEvent oneHanded = WcaEvent(
    id: '3x3-oh',
    name: '3×3 One-Handed',
    shortName: 'OH',
    family: PuzzleFamily.cube,
    cubeSize: 3,
    modifier: PuzzleModifier.oneHanded,
    format: EventFormat.ao5,
    group: EventGroup.special,
    puzzle: PuzzleSpec.cube3x3,
    isRaceable: true,
    isQuickMatch: true,
  );

  static const WcaEvent clock = WcaEvent(
    id: 'clock',
    name: 'Clock',
    shortName: 'Clock',
    family: PuzzleFamily.clock,
    format: EventFormat.ao5,
    group: EventGroup.otherPuzzles,
    isRaceable: true,
  );

  static const WcaEvent megaminx = WcaEvent(
    id: 'megaminx',
    name: 'Megaminx',
    shortName: 'Mega',
    family: PuzzleFamily.dodecahedron,
    format: EventFormat.ao5,
    group: EventGroup.otherPuzzles,
    isRaceable: true,
  );

  static const WcaEvent pyraminx = WcaEvent(
    id: 'pyraminx',
    name: 'Pyraminx',
    shortName: 'Pyra',
    family: PuzzleFamily.tetrahedron,
    format: EventFormat.ao5,
    group: EventGroup.otherPuzzles,
    isRaceable: true,
  );

  static const WcaEvent skewb = WcaEvent(
    id: 'skewb',
    name: 'Skewb',
    shortName: 'Skewb',
    family: PuzzleFamily.skewb,
    format: EventFormat.ao5,
    group: EventGroup.otherPuzzles,
    isRaceable: true,
  );

  static const WcaEvent square1 = WcaEvent(
    id: 'square-1',
    name: 'Square-1',
    shortName: 'Sq-1',
    family: PuzzleFamily.square1,
    format: EventFormat.ao5,
    group: EventGroup.otherPuzzles,
    // Even with no scrambler yet, the notation is declared: it is what the
    // card will render the moment scrambles land, and what a server-supplied
    // Square-1 scramble already parses as.
    notation: ScrambleNotation.slashPairs,
    isRaceable: true,
  );

  static const WcaEvent blind3x3 = WcaEvent(
    id: '3x3-bld',
    name: '3×3 Blindfolded',
    shortName: '3BLD',
    family: PuzzleFamily.cube,
    cubeSize: 3,
    modifier: PuzzleModifier.blindfolded,
    // Regulation 9b3a.
    format: EventFormat.bo3,
    group: EventGroup.blindfolded,
    puzzle: PuzzleSpec.cube3x3,
  );

  static const WcaEvent blind4x4 = WcaEvent(
    id: '4x4-bld',
    name: '4×4 Blindfolded',
    shortName: '4BLD',
    family: PuzzleFamily.cube,
    cubeSize: 4,
    modifier: PuzzleModifier.blindfolded,
    format: EventFormat.bo3,
    group: EventGroup.blindfolded,
    puzzle: PuzzleSpec.cube4x4,
  );

  static const WcaEvent blind5x5 = WcaEvent(
    id: '5x5-bld',
    name: '5×5 Blindfolded',
    shortName: '5BLD',
    family: PuzzleFamily.cube,
    cubeSize: 5,
    modifier: PuzzleModifier.blindfolded,
    format: EventFormat.bo3,
    group: EventGroup.blindfolded,
    puzzle: PuzzleSpec.cube5x5,
  );

  static const WcaEvent fewestMoves = WcaEvent(
    id: '3x3-fmc',
    name: '3×3 Fewest Moves',
    shortName: 'FMC',
    family: PuzzleFamily.cube,
    cubeSize: 3,
    modifier: PuzzleModifier.fewestMoves,
    // Regulation 9b4a permits Bo1/Bo2 or Mo3. Mo3 is the one a practising
    // cuber tracks, so it is what the session cards show.
    format: EventFormat.mo3,
    group: EventGroup.special,
    puzzle: PuzzleSpec.cube3x3,
    resultKind: ResultKind.moveCount,
    attemptLimit: Duration(hours: 1),
  );

  static const WcaEvent multiBlind = WcaEvent(
    id: '3x3-mbld',
    name: '3×3 Multi-Blind',
    shortName: 'MBLD',
    family: PuzzleFamily.cube,
    cubeSize: 3,
    modifier: PuzzleModifier.multiBlind,
    // Regulation 9b5a is "Best of X" with X of 1, 2 or 3. A solo session has
    // no round, so one attempt is the unit.
    format: EventFormat.bo1,
    group: EventGroup.special,
    puzzle: PuzzleSpec.cube3x3,
    notation: ScrambleNotation.multiScramble,
    resultKind: ResultKind.multiBlind,
    // The default cube count when an attempt starts. The user picks the real
    // number when recording the result.
    scrambleCount: 3,
    attemptLimit: Duration(hours: 1),
  );

  /// All seventeen, in picker order.
  static const List<WcaEvent> all = <WcaEvent>[
    cube2x2,
    cube3x3,
    cube4x4,
    cube5x5,
    cube6x6,
    cube7x7,
    megaminx,
    pyraminx,
    skewb,
    square1,
    clock,
    blind3x3,
    blind4x4,
    blind5x5,
    oneHanded,
    fewestMoves,
    multiBlind,
  ];

  static final Map<String, WcaEvent> _byId = <String, WcaEvent>{
    for (final WcaEvent e in all) e.id: e,
  };

  /// Looks up an event id, falling back to 3×3.
  ///
  /// Lenient on purpose: this parses ids that arrived over the wire, and a
  /// server that grows an eighteenth event before the client does should not
  /// crash the timer. The picker only ever offers ids from [all].
  static WcaEvent fromId(String? id) => _byId[id] ?? cube3x3;

  /// Whether [id] is one the client knows.
  static bool isKnown(String id) => _byId.containsKey(id);

  static List<WcaEvent> inGroup(EventGroup group) =>
      all.where((WcaEvent e) => e.group == group).toList();

  /// Events with a scrambler today — twelve of the seventeen: the six NxN
  /// cubes, plus the six modifier events, which reuse their base puzzle's
  /// NxN scrambler rather than needing one of their own.
  static List<WcaEvent> get scramblable =>
      all.where((WcaEvent e) => e.hasScrambler).toList();

  /// **Which events are raceable at launch.**
  ///
  /// A race needs three things the app can actually provide: a scramble both
  /// players get (so no un-scramblable puzzle), a result the client can
  /// measure and submit the instant it happens (so no Fewest Moves, whose
  /// result is a written solution, and no Multi-Blind, whose attempt is an
  /// hour), and a solve short enough that two strangers will both stay for it.
  ///
  /// Blindfolded is excluded for a fourth reason: the memorisation phase is
  /// part of the timed attempt and nothing on screen can tell it from stalling
  /// — a race on it is a race on the honour system, which is not a race.
  ///
  /// So: every NxN plus One-Handed, once they have scramblers. That is a
  /// decision, not an accident — [isQuickMatch] then narrows it further.
  static List<WcaEvent> get raceableEvents =>
      all.where((WcaEvent e) => e.isRaceable && e.hasScrambler).toList();

  /// Events quick match will search for.
  ///
  /// Narrower than [raceableEvents] on purpose. Matchmaking on `6x6 quick
  /// match` would sit in a search screen forever, because the pool for it is
  /// realistically empty — a two-minute solve is not something people queue
  /// for at random. Quick match therefore offers only 2×2, 3×3 and One-Handed,
  /// which is where the population is; everything else in [raceableEvents] is
  /// raceable in a **private room**, where you already know your opponent is
  /// on the other side and willing to sit through it.
  static List<WcaEvent> get quickMatchEvents =>
      all.where((WcaEvent e) => e.isQuickMatch && e.hasScrambler).toList();
}
