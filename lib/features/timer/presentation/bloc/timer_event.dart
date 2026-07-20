part of 'timer_bloc.dart';

sealed class TimerEvent extends Equatable {
  const TimerEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// Screen opened: subscribe to the session and propose a first scramble.
class TimerStarted extends TimerEvent {
  const TimerStarted();
}

// --- Touch input ------------------------------------------------------------
// The screen reports raw press down/up; the bloc decides what they mean, which
// depends on the current status and the user's timer style. Widgets never
// interpret a gesture themselves.

class TimerPressedDown extends TimerEvent {
  const TimerPressedDown();
}

class TimerPressedUp extends TimerEvent {
  const TimerPressedUp();
}

// --- Internal, emitted by the bloc's own subscriptions -----------------------

class TimerSolveTicked extends TimerEvent {
  const TimerSolveTicked(this.elapsed);

  final Duration elapsed;

  @override
  List<Object?> get props => <Object?>[elapsed];
}

class TimerInspectionTicked extends TimerEvent {
  const TimerInspectionTicked(this.elapsed);

  final Duration elapsed;

  @override
  List<Object?> get props => <Object?>[elapsed];
}

class TimerHoldTicked extends TimerEvent {
  const TimerHoldTicked(this.held);

  final Duration held;

  @override
  List<Object?> get props => <Object?>[held];
}

class TimerSessionUpdated extends TimerEvent {
  const TimerSessionUpdated(this.solves);

  final List<Solve> solves;

  @override
  List<Object?> get props => <Object?>[solves];
}

// --- User actions -----------------------------------------------------------

class TimerScrambleRequested extends TimerEvent {
  const TimerScrambleRequested();
}

/// The user picked a different scramble source (Random / WCA comps / Last used).
class TimerScrambleSourceChanged extends TimerEvent {
  const TimerScrambleSourceChanged(this.source);

  final ScrambleSource source;

  @override
  List<Object?> get props => <Object?>[source];
}

class TimerEventChanged extends TimerEvent {
  const TimerEventChanged(this.event);

  final String event;

  @override
  List<Object?> get props => <Object?>[event];
}

/// Apply or clear a penalty on the solve just completed.
class TimerPenaltyChanged extends TimerEvent {
  const TimerPenaltyChanged(this.penalty);

  final Penalty penalty;

  @override
  List<Object?> get props => <Object?>[penalty];
}

class TimerPreferencesChanged extends TimerEvent {
  const TimerPreferencesChanged(this.preferences);

  final TimerPreferences preferences;

  @override
  List<Object?> get props => <Object?>[preferences];
}

class TimerSessionCleared extends TimerEvent {
  const TimerSessionCleared();
}

class TimerFailureDismissed extends TimerEvent {
  const TimerFailureDismissed();
}
