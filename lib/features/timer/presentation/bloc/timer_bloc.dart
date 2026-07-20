import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/util/ticker.dart';
import '../../domain/entities/penalty.dart';
import '../../domain/entities/event_format.dart';
import '../../domain/entities/scramble.dart';
import '../../domain/entities/scramble_source.dart';
import '../../domain/entities/solve.dart';
import '../../domain/entities/solve_result.dart';
import '../../domain/entities/timer_preferences.dart';
import '../../domain/entities/wca_event.dart';
import '../../domain/repositories/solve_repository.dart';
import '../../domain/usecases/compute_averages.dart';
import '../../domain/usecases/generate_scramble.dart';
import '../../domain/usecases/grade_inspection.dart';
import '../../domain/usecases/session_statistics.dart';

part 'timer_event.dart';
part 'timer_state.dart';

/// The timer state machine.
///
/// ```
///                    ┌──────────────────────────────┐
///                    ▼                              │
///   idle ──▶ inspecting ──▶ ready ──▶ running ──▶ stopped
///     │                       ▲                     │
///     └───────────────────────┘  (inspection off)   │
///     ▲                                             │
///     └─────────────────────────────────────────────┘
/// ```
///
/// Two settings reshape it:
///   * **inspection off** skips `inspecting` — `idle` arms straight to `ready`.
///   * **[TimerStyle.tap]** skips `ready` — there is no hold to arm, a tap
///     starts and a tap stops.
///
/// All gesture interpretation lives here. The screen reports raw
/// [TimerPressedDown] / [TimerPressedUp] and renders whatever status comes
/// back; it never decides that a press "means" start.
class TimerBloc extends Bloc<TimerEvent, TimerState> {
  TimerBloc({
    required SolveRepository repository,
    required GenerateScramble generateScramble,
    required AnalyticsService analytics,
    Ticker ticker = const RealTicker(),
    String Function()? idFactory,
  })  : _repository = repository,
        _generateScramble = generateScramble,
        _analytics = analytics,
        _ticker = ticker,
        _idFactory = idFactory ?? _defaultIdFactory,
        super(const TimerState()) {
    on<TimerStarted>(_onStarted);
    on<TimerPressedDown>(_onPressedDown);
    on<TimerPressedUp>(_onPressedUp);
    on<TimerSolveTicked>(_onSolveTicked);
    on<TimerInspectionTicked>(_onInspectionTicked);
    on<TimerHoldTicked>(_onHoldTicked);
    on<TimerSessionUpdated>(_onSessionUpdated);
    on<TimerScrambleRequested>(_onScrambleRequested);
    on<TimerScrambleSourceChanged>(_onScrambleSourceChanged);
    on<TimerEventChanged>(_onEventChanged);
    on<TimerPenaltyChanged>(_onPenaltyChanged);
    on<TimerPreferencesChanged>(_onPreferencesChanged);
    on<TimerManualResultSubmitted>(_onManualResult);
    on<TimerManualResultCancelled>(
      (TimerManualResultCancelled _, Emitter<TimerState> emit) => emit(
        state.copyWith(
          awaitingManualResult: false,
          status: TimerStatus.idle,
          elapsed: Duration.zero,
        ),
      ),
    );
    on<TimerSessionCleared>(_onSessionCleared);
    on<TimerFailureDismissed>(
      (TimerFailureDismissed _, Emitter<TimerState> emit) =>
          emit(state.copyWith(clearFailure: true)),
    );
  }

  final SolveRepository _repository;
  final GenerateScramble _generateScramble;
  final AnalyticsService _analytics;
  final Ticker _ticker;
  final String Function() _idFactory;

  static const GradeInspection _grade = GradeInspection();

  StreamSubscription<Duration>? _solveSub;
  StreamSubscription<Duration>? _inspectionSub;
  StreamSubscription<Duration>? _holdSub;
  StreamSubscription<List<Solve>>? _sessionSub;

  /// A press that stopped the solve must not also be read as the start of the
  /// next one. Set when a press is consumed, cleared on the matching release.
  bool _swallowNextRelease = false;

  static String _defaultIdFactory() =>
      'c${DateTime.now().microsecondsSinceEpoch}';

  // --- Lifecycle -------------------------------------------------------------

  Future<void> _onStarted(
    TimerStarted event,
    Emitter<TimerState> emit,
  ) async {
    emit(state.copyWith(scramble: _newScramble(state.event)));

    await _sessionSub?.cancel();
    _sessionSub = _repository.watchSession().listen(
          (List<Solve> solves) => add(TimerSessionUpdated(solves)),
        );
  }

  void _onSessionUpdated(
    TimerSessionUpdated event,
    Emitter<TimerState> emit,
  ) =>
      emit(state.copyWith(sessionSolves: event.solves));

  // --- Touch handling --------------------------------------------------------

  Future<void> _onPressedDown(
    TimerPressedDown event,
    Emitter<TimerState> emit,
  ) async {
    // Fewest Moves has no timed result, so the whole-screen touch surface does
    // not apply — the screen offers a move-count field instead, and a stray
    // press must not start a stopwatch that means nothing.
    if (state.eventSpec.isManualEntry) return;
    if (state.awaitingManualResult) return;

    switch (state.status) {
      case TimerStatus.running:
        // Stop on press, not release — a solve ends the instant the hands land.
        // Awaited, not fired-and-forgotten: `emit` is only valid for as long as
        // the handler is running.
        _swallowNextRelease = true;
        await _stopSolve(emit);

      case TimerStatus.stopped:
        // Consume this press to return to idle. Without this, the press that
        // acknowledges a finished solve would immediately arm the next one.
        _swallowNextRelease = true;
        emit(
          state.copyWith(
            status: TimerStatus.idle,
            elapsed: Duration.zero,
            inspectionElapsed: Duration.zero,
            holdProgress: 0,
          ),
        );

      case TimerStatus.idle:
        // Hold-to-start arms from idle only when inspection is off; with
        // inspection on, idle's press begins inspection on release instead.
        if (state.preferences.style == TimerStyle.hold &&
            !state.preferences.inspectionEnabled) {
          _beginHold();
        }

      case TimerStatus.inspecting:
        if (state.preferences.style == TimerStyle.hold) _beginHold();

      case TimerStatus.ready:
        break;
    }
  }

  Future<void> _onPressedUp(
    TimerPressedUp event,
    Emitter<TimerState> emit,
  ) async {
    if (state.eventSpec.isManualEntry || state.awaitingManualResult) return;
    if (_swallowNextRelease) {
      _swallowNextRelease = false;
      return;
    }

    switch (state.status) {
      case TimerStatus.ready:
        // Armed and released — go.
        await _cancelHold();
        _startSolve(emit);

      case TimerStatus.idle:
        await _cancelHold();
        if (state.preferences.inspectionEnabled) {
          _startInspection(emit);
        } else if (state.preferences.style == TimerStyle.tap) {
          _startSolve(emit);
        } else {
          // Released before the hold threshold — a false start, stay put.
          emit(state.copyWith(holdProgress: 0));
        }

      case TimerStatus.inspecting:
        await _cancelHold();
        if (state.preferences.style == TimerStyle.tap) {
          _startSolve(emit);
        } else {
          // Let go too early; still inspecting.
          emit(state.copyWith(holdProgress: 0));
        }

      case TimerStatus.running:
      case TimerStatus.stopped:
        break;
    }
  }

  // --- Hold arming -----------------------------------------------------------

  void _beginHold() {
    _holdSub?.cancel();
    _holdSub = _ticker
        .elapsed(interval: const Duration(milliseconds: 16))
        .listen((Duration held) => add(TimerHoldTicked(held)));
  }

  Future<void> _cancelHold() async {
    await _holdSub?.cancel();
    _holdSub = null;
  }

  Future<void> _onHoldTicked(
    TimerHoldTicked event,
    Emitter<TimerState> emit,
  ) async {
    if (state.status != TimerStatus.idle &&
        state.status != TimerStatus.inspecting) {
      return;
    }

    final double progress = (event.held.inMilliseconds /
            TimerPreferences.holdThreshold.inMilliseconds)
        .clamp(0.0, 1.0);

    if (progress >= 1) {
      await _cancelHold();
      emit(state.copyWith(status: TimerStatus.ready, holdProgress: 1));
    } else {
      emit(state.copyWith(holdProgress: progress));
    }
  }

  // --- Inspection ------------------------------------------------------------

  void _startInspection(Emitter<TimerState> emit) {
    _analytics.capture(
      'inspection_started',
      properties: <String, Object?>{'event': state.event},
    );

    emit(
      state.copyWith(
        status: TimerStatus.inspecting,
        inspectionElapsed: Duration.zero,
        elapsed: Duration.zero,
        holdProgress: 0,
        clearLastSolve: true,
      ),
    );

    _inspectionSub?.cancel();
    _inspectionSub = _ticker
        .elapsed(interval: const Duration(milliseconds: 50))
        .listen((Duration elapsed) => add(TimerInspectionTicked(elapsed)));
  }

  void _onInspectionTicked(
    TimerInspectionTicked event,
    Emitter<TimerState> emit,
  ) {
    if (state.status != TimerStatus.inspecting &&
        state.status != TimerStatus.ready) {
      return;
    }

    // Edge-triggered so each judge's call fires exactly once regardless of
    // tick rate.
    if (_grade.shouldCue(state.inspectionElapsed, event.elapsed)) {
      _analytics.capture(
        'inspection_cue',
        properties: <String, Object?>{'at_s': event.elapsed.inSeconds},
      );
    }

    emit(state.copyWith(inspectionElapsed: event.elapsed));
  }

  // --- Solving ---------------------------------------------------------------

  void _startSolve(Emitter<TimerState> emit) {
    _inspectionSub?.cancel();
    _inspectionSub = null;

    _analytics.capture(
      'solve_started',
      properties: <String, Object?>{'event': state.event},
    );

    emit(
      state.copyWith(
        status: TimerStatus.running,
        elapsed: Duration.zero,
        holdProgress: 0,
        clearLastSolve: true,
        clearFailure: true,
      ),
    );

    _solveSub?.cancel();
    _solveSub = _ticker
        .elapsed()
        .listen((Duration elapsed) => add(TimerSolveTicked(elapsed)));
  }

  void _onSolveTicked(TimerSolveTicked event, Emitter<TimerState> emit) {
    if (state.status != TimerStatus.running) return;
    emit(state.copyWith(elapsed: event.elapsed));
  }

  Future<void> _stopSolve(Emitter<TimerState> emit) async {
    await _solveSub?.cancel();
    _solveSub = null;

    final Duration finalTime = state.elapsed;

    // Inspection overrun grades into the penalty at the moment the solve
    // started — that is what the elapsed inspection clock records.
    final Penalty penalty = state.preferences.inspectionEnabled
        ? _grade(state.inspectionElapsed)
        : Penalty.none;

    // Multi-Blind stops the clock without knowing the result: `54:22` is not a
    // result until the `11/13` is beside it. Hold the time on screen, ask, and
    // write the solve when the answer comes back — a Multi-Blind row missing
    // its cube counts is not a partial record, it is a meaningless one.
    if (state.eventSpec.resultKind == ResultKind.multiBlind) {
      emit(
        state.copyWith(
          status: TimerStatus.stopped,
          elapsed: finalTime,
          holdProgress: 0,
          awaitingManualResult: true,
        ),
      );
      return;
    }

    await _recordSolve(emit,
        timeMs: finalTime.inMilliseconds, penalty: penalty);
  }

  /// Writes a finished attempt — the single path every event records through.
  ///
  /// Shared by the stopwatch ([_stopSolve]) and by hand-entered results
  /// ([_onManualResult]) so the optimistic update, the analytics event and the
  /// failure handling cannot drift apart between them.
  Future<void> _recordSolve(
    Emitter<TimerState> emit, {
    required int timeMs,
    required Penalty penalty,
    int? moveCount,
    int? solvedCount,
    int? attemptedCount,
  }) async {
    final DateTime solvedAt = DateTime.now();
    final String clientId = _idFactory();

    // Show the finished result immediately. Persistence is async and must
    // never make the user wait to see what they just did.
    final Solve optimistic = Solve(
      id: clientId,
      event: state.event,
      scramble: state.scramble.text,
      timeMs: timeMs,
      solvedAt: solvedAt,
      penalty: penalty,
      moveCount: moveCount,
      solvedCount: solvedCount,
      attemptedCount: attemptedCount,
    );

    emit(
      state.copyWith(
        status: TimerStatus.stopped,
        elapsed: Duration(milliseconds: timeMs),
        holdProgress: 0,
        lastSolve: optimistic,
        isSaving: true,
        awaitingManualResult: false,
        // A fresh scramble is proposed after every completed attempt; the one
        // just solved becomes what `Last used` re-serves.
        scramble: _newScramble(state.event),
        previousScramble: state.scramble,
      ),
    );

    _analytics.capture(
      'solve_completed',
      properties: <String, Object?>{
        'event': state.event,
        'time_ms': timeMs,
        'penalty': penalty.name,
        'result_kind': state.eventSpec.resultKind.name,
        if (moveCount != null) 'move_count': moveCount,
        if (solvedCount != null) 'solved_count': solvedCount,
        if (attemptedCount != null) 'attempted_count': attemptedCount,
        // Deliberately absent: `is_pb`. The server owns it (docs → API Design)
        // and the client must not guess it.
      },
    );

    final Result<Solve> result = await _repository.addSolve(
      event: optimistic.event,
      scramble: optimistic.scramble,
      timeMs: optimistic.timeMs,
      penalty: penalty,
      solvedAt: solvedAt,
      clientId: clientId,
      moveCount: moveCount,
      solvedCount: solvedCount,
      attemptedCount: attemptedCount,
    );

    if (isClosed) return;

    switch (result) {
      case Ok<Solve>(:final Solve value):
        emit(state.copyWith(lastSolve: value, isSaving: false));
      case Err<Solve>(:final Failure failure):
        // The result stays on screen — a failed write loses the record, not
        // the user's attempt.
        emit(state.copyWith(isSaving: false, failure: failure));
    }
  }

  /// A result the stopwatch could not produce — see
  /// [TimerManualResultSubmitted].
  Future<void> _onManualResult(
    TimerManualResultSubmitted event,
    Emitter<TimerState> emit,
  ) async {
    // Fewest Moves is not timed against the clock, so an attempt with no
    // measured duration is normal and records as zero rather than being
    // rejected.
    final int timeMs = event.timeMs ?? state.elapsed.inMilliseconds;

    await _recordSolve(
      emit,
      timeMs: timeMs,
      // A `+2` is an inspection penalty on a timed solve. Neither of these
      // events has one, so nothing can be carried in from the timer here.
      penalty: Penalty.none,
      moveCount: event.moveCount,
      solvedCount: event.solvedCount,
      attemptedCount: event.attemptedCount,
    );
  }

  // --- Scramble & event ------------------------------------------------------

  /// A fresh scramble for [eventId].
  ///
  /// Returns [Scramble.empty] for an event with no scrambler yet, which the
  /// card renders as an explicit "scrambles coming" state rather than a
  /// silently substituted 3×3 scramble.
  Scramble _newScramble(String eventId) {
    final WcaEvent event = WcaEvent.fromId(eventId);
    final Scramble scramble = _generateScramble.scrambleFor(event);
    _analytics.capture(
      'scramble_generated',
      properties: <String, Object?>{
        'event': eventId,
        'source': state.scrambleSource.wire,
        'available': event.hasScrambler,
      },
    );
    return scramble;
  }

  /// Only `random` is generated locally. WCA-competition scrambles need a
  /// dataset the MVP doesn't ship, so the segment is selectable but explains
  /// itself rather than quietly serving a random scramble under a WCA label —
  /// which would be a lie about provenance, and provenance is the whole point
  /// of the control.
  void _onScrambleSourceChanged(
    TimerScrambleSourceChanged event,
    Emitter<TimerState> emit,
  ) {
    if (state.isImmersive || event.source == state.scrambleSource) return;

    switch (event.source) {
      case ScrambleSource.random:
        emit(
          state.copyWith(
            scrambleSource: event.source,
            scramble: _newScramble(state.event),
            previousScramble: state.scramble,
          ),
        );
      case ScrambleSource.reused:
        final Scramble? previous = state.previousScramble;
        emit(
          state.copyWith(
            scrambleSource: event.source,
            // Nothing solved yet this session — keep what's on screen rather
            // than blanking the card.
            scramble: previous ?? state.scramble,
          ),
        );
      case ScrambleSource.wca:
        emit(state.copyWith(scrambleSource: event.source));
    }
  }

  void _onScrambleRequested(
    TimerScrambleRequested event,
    Emitter<TimerState> emit,
  ) {
    // Never swap the scramble out from under a solve in progress.
    if (state.isImmersive) return;
    emit(state.copyWith(scramble: _newScramble(state.event)));
  }

  void _onEventChanged(TimerEventChanged event, Emitter<TimerState> emit) {
    if (event.event == state.event) return;

    // Most-recent-first, no duplicates, capped — this feeds the picker's
    // `Recent` group, and a list longer than the group can show is just memory
    // nobody reads.
    final List<String> recents = <String>[
      event.event,
      ...state.recentEvents.where((String id) => id != event.event),
    ].take(5).toList();

    emit(
      state.copyWith(
        event: event.event,
        scramble: _newScramble(event.event),
        status: TimerStatus.idle,
        elapsed: Duration.zero,
        inspectionElapsed: Duration.zero,
        awaitingManualResult: false,
        recentEvents: recents,
        clearLastSolve: true,
      ),
    );
  }

  // --- Penalties -------------------------------------------------------------

  Future<void> _onPenaltyChanged(
    TimerPenaltyChanged event,
    Emitter<TimerState> emit,
  ) async {
    final Solve? solve = state.lastSolve;
    if (solve == null) return;

    // Optimistic — the control should feel instant.
    emit(state.copyWith(lastSolve: solve.copyWith(penalty: event.penalty)));

    _analytics.capture(
      'penalty_applied',
      properties: <String, Object?>{'type': event.penalty.name},
    );

    final Result<Solve> result =
        await _repository.updatePenalty(solve.id, event.penalty);
    if (isClosed) return;

    switch (result) {
      case Ok<Solve>(:final Solve value):
        emit(state.copyWith(lastSolve: value));
      case Err<Solve>(:final Failure failure):
        // Roll back to the penalty the server still believes in.
        emit(state.copyWith(lastSolve: solve, failure: failure));
    }
  }

  // --- Settings & session ----------------------------------------------------

  void _onPreferencesChanged(
    TimerPreferencesChanged event,
    Emitter<TimerState> emit,
  ) =>
      emit(state.copyWith(preferences: event.preferences));

  Future<void> _onSessionCleared(
    TimerSessionCleared event,
    Emitter<TimerState> emit,
  ) async {
    final Result<void> result = await _repository.clearSession();
    if (isClosed) return;

    if (result case Err<void>(:final Failure failure)) {
      emit(state.copyWith(failure: failure));
      return;
    }
    emit(
      state.copyWith(
        status: TimerStatus.idle,
        elapsed: Duration.zero,
        inspectionElapsed: Duration.zero,
        clearLastSolve: true,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _solveSub?.cancel();
    await _inspectionSub?.cancel();
    await _holdSub?.cancel();
    await _sessionSub?.cancel();
    return super.close();
  }
}
