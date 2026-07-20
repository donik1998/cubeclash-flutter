part of 'race_bloc.dart';

sealed class RaceEvent extends Equatable {
  const RaceEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// Open the socket. Fired when the Race tab mounts.
class RaceOpened extends RaceEvent {
  const RaceOpened();
}

/// Enqueue for a quick match, or open a private room.
class RaceRequested extends RaceEvent {
  const RaceRequested(this.mode, {this.event = '3x3'});

  final RaceMode mode;

  /// Which event to race. Quick match only offers the short, populated events
  /// (`WcaEvent.quickMatchEvents`); a private room takes anything raceable.
  final String event;

  @override
  List<Object?> get props => <Object?>[mode, event];
}

class RaceJoinRequested extends RaceEvent {
  const RaceJoinRequested(this.code);

  final String code;

  @override
  List<Object?> get props => <Object?>[code];
}

/// Cancel matchmaking, or leave a room before it starts.
class RaceCancelled extends RaceEvent {
  const RaceCancelled();
}

class RaceReadyPressed extends RaceEvent {
  const RaceReadyPressed();
}

/// You stopped your timer. Idempotent — a second one is ignored.
class RaceSolveStopped extends RaceEvent {
  const RaceSolveStopped();
}

/// Back to the lobby from a result.
class RaceDismissed extends RaceEvent {
  const RaceDismissed();
}

class RaceRematchRequested extends RaceEvent {
  const RaceRematchRequested();
}

// --- Internal: driven by the gateway's streams and the ticker ----------------

class RaceStateReceived extends RaceEvent {
  const RaceStateReceived(this.payload);

  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => <Object?>[payload];
}

class RaceReadyUpdateReceived extends RaceEvent {
  const RaceReadyUpdateReceived(this.payload);

  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => <Object?>[payload];
}

class RaceCountdownReceived extends RaceEvent {
  const RaceCountdownReceived(this.n);

  final int n;

  @override
  List<Object?> get props => <Object?>[n];
}

class RaceScrambleReceived extends RaceEvent {
  const RaceScrambleReceived(this.scramble);

  final String scramble;

  @override
  List<Object?> get props => <Object?>[scramble];
}

class RaceOpponentProgressReceived extends RaceEvent {
  const RaceOpponentProgressReceived(this.runningMs);

  final int runningMs;

  @override
  List<Object?> get props => <Object?>[runningMs];
}

class RaceResultReceived extends RaceEvent {
  const RaceResultReceived(this.payload);

  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => <Object?>[payload];
}

class RaceConnectionChanged extends RaceEvent {
  const RaceConnectionChanged(this.connection);

  final GatewayConnection connection;

  @override
  List<Object?> get props => <Object?>[connection];
}

class RaceSolveTicked extends RaceEvent {
  const RaceSolveTicked(this.elapsed);

  final Duration elapsed;

  @override
  List<Object?> get props => <Object?>[elapsed];
}

class RaceSearchTicked extends RaceEvent {
  const RaceSearchTicked(this.elapsed);

  final Duration elapsed;

  @override
  List<Object?> get props => <Object?>[elapsed];
}
