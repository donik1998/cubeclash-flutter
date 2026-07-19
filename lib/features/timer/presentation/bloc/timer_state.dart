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
    this.scramble = '',
    this.elapsed = Duration.zero,
    this.inspectionElapsed = Duration.zero,
    this.holdProgress = 0,
    this.sessionSolves = const <Solve>[],
    this.lastSolve,
    this.preferences = const TimerPreferences(),
    this.failure,
    this.isSaving = false,
  });

  final TimerStatus status;
  final String event;
  final String scramble;

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

  /// Session ao5 / ao12 / best, computed from effective times.
  ///
  /// A DNF contributes `null`, which [ComputeAverages] treats as the slowest
  /// possible time — so it is trimmed first and only poisons an average if a
  /// second DNF forces it past the trim.
  List<int?> get _effectiveTimes =>
      sessionSolves.map((Solve s) => s.effectiveTimeMs).toList();

  int? get sessionAo5 => const ComputeAverages().average(_effectiveTimes, 5);
  int? get sessionAo12 => const ComputeAverages().average(_effectiveTimes, 12);

  int? get sessionBest {
    final List<int> valid = _effectiveTimes.whereType<int>().toList()..sort();
    return valid.isEmpty ? null : valid.first;
  }

  TimerState copyWith({
    TimerStatus? status,
    String? event,
    String? scramble,
    Duration? elapsed,
    Duration? inspectionElapsed,
    double? holdProgress,
    List<Solve>? sessionSolves,
    TimerPreferences? preferences,
    bool? isSaving,
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
        elapsed: elapsed ?? this.elapsed,
        inspectionElapsed: inspectionElapsed ?? this.inspectionElapsed,
        holdProgress: holdProgress ?? this.holdProgress,
        sessionSolves: sessionSolves ?? this.sessionSolves,
        lastSolve: clearLastSolve ? null : (lastSolve ?? this.lastSolve),
        preferences: preferences ?? this.preferences,
        failure: clearFailure ? null : (failure ?? this.failure),
        isSaving: isSaving ?? this.isSaving,
      );

  @override
  List<Object?> get props => <Object?>[
        status,
        event,
        scramble,
        elapsed,
        inspectionElapsed,
        holdProgress,
        sessionSolves,
        lastSolve,
        preferences,
        failure,
        isSaving,
      ];
}
