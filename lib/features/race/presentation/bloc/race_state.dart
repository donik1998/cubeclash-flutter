part of 'race_bloc.dart';

/// What the Race feature is doing, from the UI's point of view.
///
/// This is *not* the same thing as [RaceStatus]. That is the server's room
/// lifecycle; this adds the client-only phases either side of it — sitting in
/// the lobby, queueing for a match, and reviewing a result.
enum RacePhase {
  /// In the lobby. Nothing in flight.
  idle,

  /// Queued for a quick match, or holding a private room open.
  searching,

  /// Both players present, confirming ready.
  readyCheck,

  /// 3 · 2 · 1 · GO.
  countdown,

  /// Solving. Full-screen.
  racing,

  /// Submitted, waiting for the server to settle. The opponent may still be
  /// going — this is the "you're done, they're not" gap.
  submitted,

  /// Result received.
  settled,
}

class RaceState extends Equatable {
  const RaceState({
    this.phase = RacePhase.idle,
    this.room,
    this.scramble = '',
    this.countdown,
    this.elapsed = Duration.zero,
    this.yourTimeMs,
    this.result,
    this.connection = GatewayConnection.disconnected,
    this.searchElapsed = Duration.zero,
    this.failure,
    this.mode = RaceMode.quick,
  });

  final RacePhase phase;
  final RaceRoom? room;

  /// Revealed by the server at GO. Empty until then — the client must not know
  /// the scramble early, which is half the point of a synchronised start.
  final String scramble;

  /// Current countdown tick. `0` means GO; null when not counting down.
  final int? countdown;

  /// Your running solve time.
  final Duration elapsed;

  /// Your submitted time. Non-null is the idempotency guard — once set, a
  /// second stop is ignored.
  final int? yourTimeMs;

  final RaceResult? result;
  final GatewayConnection connection;

  /// How long the matchmaking queue has been running.
  final Duration searchElapsed;

  final Failure? failure;
  final RaceMode mode;

  RacePlayer? get you => room?.you;
  RacePlayer? get opponent => room?.opponent;

  /// Full-screen, outside the shell.
  ///
  /// Starts at the **ready check**, not at the countdown: the Figma frame for
  /// the ready room (`34:106`) has this screen's chrome and no nav bar. Once
  /// you are matched with a real person, drifting off to another tab strands
  /// them in a room waiting on a confirmation that is never coming, so leaving
  /// is made deliberate — the × in the header — from that moment on.
  bool get isImmersive =>
      phase == RacePhase.readyCheck ||
      phase == RacePhase.countdown ||
      phase == RacePhase.racing ||
      phase == RacePhase.submitted;

  /// You've submitted and are waiting on them.
  bool get waitingForOpponent => phase == RacePhase.submitted;

  /// The opponent dropped and is inside the grace window. Surfaced in the UI so
  /// a frozen progress bar is explained rather than mysterious.
  bool get opponentReconnecting => opponent?.connected == false;

  /// Your own transport is down mid-race.
  bool get disconnected =>
      connection == GatewayConnection.disconnected &&
      phase != RacePhase.idle &&
      phase != RacePhase.settled;

  RaceState copyWith({
    RacePhase? phase,
    RaceRoom? room,
    String? scramble,
    Duration? elapsed,
    Duration? searchElapsed,
    GatewayConnection? connection,
    RaceMode? mode,
    // Nullable fields need explicit clears.
    int? countdown,
    bool clearCountdown = false,
    int? yourTimeMs,
    bool clearYourTime = false,
    RaceResult? result,
    bool clearResult = false,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      RaceState(
        phase: phase ?? this.phase,
        room: room ?? this.room,
        scramble: scramble ?? this.scramble,
        countdown: clearCountdown ? null : (countdown ?? this.countdown),
        elapsed: elapsed ?? this.elapsed,
        yourTimeMs: clearYourTime ? null : (yourTimeMs ?? this.yourTimeMs),
        result: clearResult ? null : (result ?? this.result),
        connection: connection ?? this.connection,
        searchElapsed: searchElapsed ?? this.searchElapsed,
        failure: clearFailure ? null : (failure ?? this.failure),
        mode: mode ?? this.mode,
      );

  @override
  List<Object?> get props => <Object?>[
        phase,
        room,
        scramble,
        countdown,
        elapsed,
        yourTimeMs,
        result,
        connection,
        searchElapsed,
        failure,
        mode,
      ];
}
