part of 'timer_bloc.dart';

/// Where the timer is in its lifecycle.
///
/// `idle → inspecting → ready → running → stopped → idle`
///
/// With inspection off the `inspecting` step is skipped entirely; with
/// [TimerStyle.tap] the `ready` step is skipped (there is no hold to arm).
enum TimerStatus {
  /// Waiting. Shows the last solve's time, or 0.00 for a fresh session.
  idle,

  /// 15-second WCA inspection is running.
  inspecting,

  /// Held past the threshold — armed. Release starts the solve.
  ready,

  /// Solve in progress. Full-screen, all chrome hidden.
  running,

  /// Solve finished and recorded. Penalty controls are live.
  stopped,
}

class TimerState extends Equatable {
  const TimerState({
    this.status = TimerStatus.idle,
    this.event = '3x3',
    this.scramble = const Scramble.empty(),
    this.scrambleSource = ScrambleSource.random,
    this.previousScramble,
    this.elapsed = Duration.zero,
    this.inspectionElapsed = Duration.zero,
    this.holdProgress = 0,
    this.sessionSolves = const <Solve>[],
    this.lastSolve,
    this.preferences = const TimerPreferences(),
    this.failure,
    this.isSaving = false,
    this.awaitingManualResult = false,
    this.recentEvents = const <String>['3x3'],
  });

  final TimerStatus status;

  /// Event **id** (`3x3`, `4x4-bld`, `3x3-fmc`). The id rather than the
  /// [WcaEvent] itself, because it is what goes on a `Solve` and over the
  /// wire; [eventSpec] resolves it.
  final String event;

  /// The current scramble, structure intact — see [Scramble] for why this is
  /// no longer a `String`.
  final Scramble scramble;

  /// Which source the scramble card is showing (Figma: `scrtabs`).
  final ScrambleSource scrambleSource;

  /// The scramble before the current one — what `Last used` re-serves.
  final Scramble? previousScramble;

  /// Solve time so far (or final, once stopped).
  final Duration elapsed;

  /// Time spent in inspection — grades into the +2 / DNF penalty on start.
  final Duration inspectionElapsed;

  /// 0 → 1 across the hold threshold. Drives the arming affordance.
  final double holdProgress;

  /// The current session, oldest first.
  final List<Solve> sessionSolves;

  /// The solve just completed — the one the penalty controls act on.
  final Solve? lastSolve;

  final TimerPreferences preferences;

  /// Set when a write failed. Surfaced as a dismissible message; the solve time
  /// itself is never lost from [lastSolve] because of it.
  final Failure? failure;

  final bool isSaving;

  /// The attempt is over but the result is not known yet, because this event's
  /// result cannot be measured by a stopwatch.
  ///
  /// Multi-Blind stops the clock and *then* asks how many cubes came out; the
  /// solve is deliberately not written until it does, because a Multi-Blind
  /// record without its solved/attempted pair is not a partial record, it is a
  /// meaningless one. See [TimerManualResultSubmitted].
  final bool awaitingManualResult;

  /// Event ids most recently practised, most recent first — what the picker
  /// pins to the top. Client-side only; not a server concept.
  final List<String> recentEvents;

  /// Nav bar, scramble card and controls all hide during the solve — the
  /// running state is deliberately a bare readout (docs → Navigation & IA:
  /// "Solving state = full-screen minimal").
  bool get isImmersive =>
      status == TimerStatus.inspecting ||
      status == TimerStatus.ready ||
      status == TimerStatus.running;

  /// Penalty the current inspection would incur if the solve started now.
  Penalty get pendingInspectionPenalty =>
      const GradeInspection().call(inspectionElapsed);

  /// The selected event's full specification.
  WcaEvent get eventSpec => WcaEvent.fromId(event);

  /// The session, restricted to the selected event.
  ///
  /// A session can now hold more than one event, and an ao5 that mixed a 2×2
  /// into a 7×7 would be a meaningless number presented as a real one.
  List<Solve> get eventSolves =>
      sessionSolves.where((Solve s) => s.event == event).toList();

  /// The three cards under the timer, chosen by the event's competition format
  /// — see [EventFormat.sessionStats].
  ///
  /// A DNF contributes `null`, which [ComputeAverages] treats as the slowest
  /// possible attempt — so it is trimmed first and only poisons an average if
  /// a second DNF forces it past the trim.
  List<SessionStatValue> get sessionStats =>
      const SessionStatistics()(eventSpec, eventSolves);

  TimerState copyWith({
    TimerStatus? status,
    String? event,
    Scramble? scramble,
    ScrambleSource? scrambleSource,
    Scramble? previousScramble,
    Duration? elapsed,
    Duration? inspectionElapsed,
    double? holdProgress,
    List<Solve>? sessionSolves,
    TimerPreferences? preferences,
    bool? isSaving,
    bool? awaitingManualResult,
    List<String>? recentEvents,
    // Nullable fields need an explicit "clear" flag — `??` can't distinguish
    // "leave it alone" from "set it back to null".
    Solve? lastSolve,
    bool clearLastSolve = false,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      TimerState(
        status: status ?? this.status,
        event: event ?? this.event,
        scramble: scramble ?? this.scramble,
        scrambleSource: scrambleSource ?? this.scrambleSource,
        previousScramble: previousScramble ?? this.previousScramble,
        elapsed: elapsed ?? this.elapsed,
        inspectionElapsed: inspectionElapsed ?? this.inspectionElapsed,
        holdProgress: holdProgress ?? this.holdProgress,
        sessionSolves: sessionSolves ?? this.sessionSolves,
        lastSolve: clearLastSolve ? null : (lastSolve ?? this.lastSolve),
        preferences: preferences ?? this.preferences,
        failure: clearFailure ? null : (failure ?? this.failure),
        isSaving: isSaving ?? this.isSaving,
        awaitingManualResult: awaitingManualResult ?? this.awaitingManualResult,
        recentEvents: recentEvents ?? this.recentEvents,
      );

  @override
  List<Object?> get props => <Object?>[
        status,
        event,
        scramble,
        scrambleSource,
        previousScramble,
        elapsed,
        inspectionElapsed,
        holdProgress,
        sessionSolves,
        lastSolve,
        preferences,
        failure,
        isSaving,
        awaitingManualResult,
        recentEvents,
      ];
}
