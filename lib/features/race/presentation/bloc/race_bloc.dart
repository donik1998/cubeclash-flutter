import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/realtime/race_gateway.dart';
import '../../../../core/util/ticker.dart';
import '../../data/models/race_dto.dart';
import '../../domain/entities/race_room.dart';

part 'race_event.dart';
part 'race_state.dart';

/// The race state machine.
///
/// ```
/// idle ──▶ searching ──▶ readyCheck ──▶ countdown ──▶ racing ──▶ submitted ──▶ settled
///   ▲          │              │                                                   │
///   └──────────┴──────────────┴───────────────────────────────────────────────────┘
///                        (cancel / dismiss)
/// ```
///
/// **The server owns the outcome.** This bloc never compares two times, never
/// decides a winner, and never computes an Elo change. It emits intent
/// (`ready`, `solve:stop`) and renders whatever `race:result` says. Everything
/// below is about keeping the *display* honest while that conversation happens.
///
/// Three failure modes get explicit handling, because a race is a distributed
/// system and all three happen in practice:
///
///  * **Duplicate submit.** A double-tap, or a tap racing the socket's ack,
///    must not send two times. [RaceState.yourTimeMs] is the guard: once set,
///    further stops are dropped. The fake gateway enforces the same rule
///    server-side, because either end can be the one that double-fires.
///  * **Opponent disconnect.** Their progress simply stops arriving, which is
///    indistinguishable from them being slow. The server tracks the grace
///    window and eventually rules; the client's job is to *say* the opponent
///    dropped rather than showing a frozen bar with no explanation.
///  * **Your own disconnect.** The solve keeps running locally — your time is
///    still real — and the submit is attempted anyway. Room state lives in
///    Redis, so reconnecting rejoins rather than forfeits.
class RaceBloc extends Bloc<RaceEvent, RaceState> {
  RaceBloc({
    required RaceGateway gateway,
    required AnalyticsService analytics,
    Ticker ticker = const RealTicker(),
    String? accessToken,
  })  : _gateway = gateway,
        _analytics = analytics,
        _ticker = ticker,
        _accessToken = accessToken,
        super(const RaceState()) {
    on<RaceOpened>(_onOpened);
    on<RaceRequested>(_onRequested);
    on<RaceJoinRequested>(_onJoinRequested);
    on<RaceCancelled>(_onCancelled);
    on<RaceReadyPressed>(_onReadyPressed);
    on<RaceSolveStopped>(_onSolveStopped);
    on<RaceDismissed>(_onDismissed);
    on<RaceRematchRequested>(_onRematchRequested);

    on<RaceStateReceived>(_onStateReceived);
    on<RaceReadyUpdateReceived>(_onReadyUpdateReceived);
    on<RaceCountdownReceived>(_onCountdownReceived);
    on<RaceScrambleReceived>(_onScrambleReceived);
    on<RaceOpponentProgressReceived>(_onOpponentProgressReceived);
    on<RaceResultReceived>(_onResultReceived);
    on<RaceResultOverdue>(_onResultOverdue);
    on<RaceConnectionChanged>(_onConnectionChanged);
    on<RaceSolveTicked>(_onSolveTicked);
    on<RaceSearchTicked>(_onSearchTicked);
  }

  final RaceGateway _gateway;
  final AnalyticsService _analytics;
  final Ticker _ticker;
  final String? _accessToken;

  final List<StreamSubscription<dynamic>> _gatewaySubs =
      <StreamSubscription<dynamic>>[];
  StreamSubscription<Duration>? _solveSub;
  StreamSubscription<Duration>? _searchSub;

  /// Watches for the gateway going silent while we wait to be settled.
  StreamSubscription<Duration>? _silenceSub;

  /// How long the gateway may say **nothing** while we sit in `submitted`
  /// before the UI offers a way out.
  ///
  /// Deliberately measured as *silence*, not as elapsed wait, so it does not
  /// have to guess how long a solve takes: during a normal race the opponent's
  /// `race:opponent_progress` arrives continuously, and once they finish the
  /// server settles immediately. Twenty seconds of nothing at all means
  /// something is wrong regardless of whether the event is a 2×2 or a 7×7 —
  /// which is exactly why this isn't a per-event timeout.
  ///
  /// It never decides an outcome. The server still owns the result; this only
  /// stops the user being trapped on a screen that has no exit.
  static const Duration silenceTimeout = Duration(seconds: 20);

  bool _connected = false;

  // --- Lifecycle -------------------------------------------------------------

  void _onOpened(RaceOpened event, Emitter<RaceState> emit) {
    if (_connected) return;
    _connected = true;

    _gateway.connect(accessToken: _accessToken);

    _gatewaySubs.addAll(<StreamSubscription<dynamic>>[
      _gateway.onState.listen((Map<String, dynamic> p) {
        _noteGatewayActivity();
        add(RaceStateReceived(p));
      }),
      _gateway.onReadyUpdate.listen((Map<String, dynamic> p) {
        _noteGatewayActivity();
        add(RaceReadyUpdateReceived(p));
      }),
      _gateway.onCountdown.listen((int n) => add(RaceCountdownReceived(n))),
      _gateway.onScramble.listen(
        (String s) => add(RaceScrambleReceived(s)),
      ),
      _gateway.onOpponentProgress.listen((int ms) {
        // The signal that matters most: while the opponent is still solving
        // this arrives continuously, so silence here is what "something is
        // wrong" actually looks like.
        _noteGatewayActivity();
        add(RaceOpponentProgressReceived(ms));
      }),
      _gateway.onResult.listen(
        (Map<String, dynamic> p) => add(RaceResultReceived(p)),
      ),
      _gateway.onConnection.listen(
        (GatewayConnection c) => add(RaceConnectionChanged(c)),
      ),
    ]);
  }

  // --- Matchmaking -----------------------------------------------------------

  void _onRequested(RaceRequested event, Emitter<RaceState> emit) {
    _analytics.capture(
      'race_search_started',
      properties: <String, Object?>{'mode': event.mode.wire},
    );

    emit(
      state.copyWith(
        phase: RacePhase.searching,
        mode: event.mode,
        searchElapsed: Duration.zero,
        clearResult: true,
        clearYourTime: true,
        clearFailure: true,
        scramble: '',
      ),
    );

    _gateway.createRace(mode: event.mode.wire, event: event.event);
    _startSearchClock();
  }

  void _onJoinRequested(RaceJoinRequested event, Emitter<RaceState> emit) {
    final String code = event.code.trim().toUpperCase();
    if (code.isEmpty) {
      emit(
        state.copyWith(
          failure: const ServerFailure('Enter an invite code.'),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        phase: RacePhase.searching,
        mode: RaceMode.private,
        searchElapsed: Duration.zero,
        clearResult: true,
        clearYourTime: true,
        clearFailure: true,
        scramble: '',
      ),
    );

    _gateway.joinByCode(code);
    _startSearchClock();
  }

  void _startSearchClock() {
    _searchSub?.cancel();
    _searchSub = _ticker
        .elapsed(interval: const Duration(seconds: 1))
        .listen((Duration d) => add(RaceSearchTicked(d)));
  }

  void _onSearchTicked(RaceSearchTicked event, Emitter<RaceState> emit) {
    if (state.phase != RacePhase.searching) return;
    emit(state.copyWith(searchElapsed: event.elapsed));
  }

  Future<void> _onCancelled(
    RaceCancelled event,
    Emitter<RaceState> emit,
  ) async {
    await _stopClocks();
    _gateway.leave();
    emit(
      const RaceState(
          phase: RacePhase.idle, connection: GatewayConnection.connected),
    );
    // Reconnect for the next attempt — leaving drops the socket.
    _connected = false;
    add(const RaceOpened());
  }

  // --- Ready check -----------------------------------------------------------

  void _onReadyPressed(RaceReadyPressed event, Emitter<RaceState> emit) {
    final RacePlayer? you = state.you;
    if (you == null || you.ready) return; // already confirmed

    _gateway.ready();
    // Optimistic: the tick should appear the instant you press it. The
    // authoritative flip arrives on race:ready_update a moment later.
    emit(
      state.copyWith(
        room: state.room?.withPlayer(
          you.userId,
          (RacePlayer p) => p.copyWith(ready: true),
        ),
      ),
    );
  }

  // --- Server-driven transitions ---------------------------------------------

  /// Restarts the silence watchdog. Called on every inbound gateway message,
  /// so the timeout measures *silence* rather than elapsed wait.
  void _noteGatewayActivity() {
    if (state.phase != RacePhase.submitted) return;
    _startSilenceWatchdog();
  }

  void _startSilenceWatchdog() {
    _silenceSub?.cancel();
    _silenceSub = _ticker
        .elapsed(interval: const Duration(seconds: 1))
        .listen((Duration since) {
      if (since >= silenceTimeout) add(const RaceResultOverdue());
    });
  }

  Future<void> _stopSilenceWatchdog() async {
    await _silenceSub?.cancel();
    _silenceSub = null;
  }

  void _onResultOverdue(RaceResultOverdue event, Emitter<RaceState> emit) {
    // Only meaningful while waiting to be settled, and only once.
    if (state.phase != RacePhase.submitted || state.resultOverdue) return;
    emit(state.copyWith(resultOverdue: true));
  }

  Future<void> _onStateReceived(
    RaceStateReceived event,
    Emitter<RaceState> emit,
  ) async {
    final RaceRoom room = RaceDto.roomFromJson(event.payload);

    // Preserve the opponent's live progress: race:state is a snapshot and does
    // not carry it, so a naive replace would blank the opponent's bar every
    // time the room changes.
    final RaceRoom merged = _preserveProgress(room);

    final RacePhase phase = switch (room.status) {
      RaceStatus.waiting =>
        room.isFull ? RacePhase.readyCheck : RacePhase.searching,
      RaceStatus.readyCheck => RacePhase.readyCheck,
      RaceStatus.countdown => RacePhase.countdown,
      RaceStatus.racing =>
        // Don't drag yourself back into `racing` after you've submitted —
        // the room stays `racing` until the opponent finishes too.
        state.yourTimeMs != null ? RacePhase.submitted : RacePhase.racing,
      RaceStatus.settled => RacePhase.settled,
    };

    if (phase == RacePhase.readyCheck && state.phase == RacePhase.searching) {
      await _stopSearchClock();
      _analytics.capture(
        'race_matched',
        properties: <String, Object?>{
          'opponent_id': merged.opponent?.userId,
          'wait_ms': state.searchElapsed.inMilliseconds,
        },
      );
    }

    emit(state.copyWith(room: merged, phase: phase));
  }

  /// Re-applies live progress/finish data the snapshot doesn't carry.
  RaceRoom _preserveProgress(RaceRoom incoming) {
    final RaceRoom? previous = state.room;
    if (previous == null) return incoming;

    return incoming.copyWith(
      players: incoming.players.map((RacePlayer p) {
        final RacePlayer? old = previous.players
            .where((RacePlayer q) => q.userId == p.userId)
            .fold<RacePlayer?>(null, (RacePlayer? acc, RacePlayer q) => q);
        if (old == null) return p;
        return p.copyWith(
          progressMs: p.progressMs ?? old.progressMs,
          finalTimeMs: p.finalTimeMs ?? old.finalTimeMs,
        );
      }).toList(),
    );
  }

  void _onReadyUpdateReceived(
    RaceReadyUpdateReceived event,
    Emitter<RaceState> emit,
  ) {
    final String userId = event.payload['user_id'] as String? ?? '';
    final bool ready = event.payload['ready'] as bool? ?? false;
    final RaceRoom? room = state.room;
    if (room == null || userId.isEmpty) return;

    emit(
      state.copyWith(
        room: room.withPlayer(
          userId,
          (RacePlayer p) => p.copyWith(ready: ready),
        ),
      ),
    );
  }

  void _onCountdownReceived(
    RaceCountdownReceived event,
    Emitter<RaceState> emit,
  ) {
    emit(
      state.copyWith(
        phase: RacePhase.countdown,
        countdown: event.n,
        elapsed: Duration.zero,
        clearYourTime: true,
      ),
    );
  }

  /// GO. The scramble arrives at the same instant for both players, and the
  /// solve clock starts here — not on a local timer we could have started early.
  void _onScrambleReceived(
    RaceScrambleReceived event,
    Emitter<RaceState> emit,
  ) {
    _gateway.solveStart();

    _analytics.capture(
      'race_solve_started',
      properties: <String, Object?>{'race_id': state.room?.id},
    );

    emit(
      state.copyWith(
        phase: RacePhase.racing,
        scramble: event.scramble,
        clearCountdown: true,
        elapsed: Duration.zero,
      ),
    );

    _solveSub?.cancel();
    _solveSub =
        _ticker.elapsed().listen((Duration d) => add(RaceSolveTicked(d)));
  }

  void _onSolveTicked(RaceSolveTicked event, Emitter<RaceState> emit) {
    if (state.phase != RacePhase.racing) return;
    emit(state.copyWith(elapsed: event.elapsed));
  }

  void _onOpponentProgressReceived(
    RaceOpponentProgressReceived event,
    Emitter<RaceState> emit,
  ) {
    final RacePlayer? opponent = state.opponent;
    if (opponent == null) return;

    emit(
      state.copyWith(
        room: state.room?.withPlayer(
          opponent.userId,
          // Progress arriving is also proof they're connected — it clears a
          // stale "reconnecting" flag without waiting for a state snapshot.
          (RacePlayer p) =>
              p.copyWith(progressMs: event.runningMs, connected: true),
        ),
      ),
    );
  }

  // --- Submitting ------------------------------------------------------------

  Future<void> _onSolveStopped(
    RaceSolveStopped event,
    Emitter<RaceState> emit,
  ) async {
    // Idempotency guard. A double-tap, or a tap that races the socket ack,
    // must never send a second time.
    if (state.yourTimeMs != null) return;
    if (state.phase != RacePhase.racing) return;

    final int timeMs = state.elapsed.inMilliseconds;
    await _stopSolveClock();

    _gateway.solveStop(timeMs);
    _analytics.capture(
      'race_solve_submitted',
      properties: <String, Object?>{'time_ms': timeMs},
    );

    emit(
      state.copyWith(
        phase: RacePhase.submitted,
        yourTimeMs: timeMs,
        elapsed: Duration(milliseconds: timeMs),
        resultOverdue: false,
      ),
    );

    // From here the only thing that ends this screen is `race:result`. If that
    // never comes, the watchdog is what stops the user being stranded.
    _startSilenceWatchdog();
  }

  Future<void> _onResultReceived(
    RaceResultReceived event,
    Emitter<RaceState> emit,
  ) async {
    await _stopClocks();

    // Authoritative. `race_completed` is a server-side analytics event — the
    // client must not emit it (docs → Observability & Analytics).
    emit(
      state.copyWith(
        phase: RacePhase.settled,
        result: RaceDto.resultFromJson(event.payload),
        clearCountdown: true,
        resultOverdue: false,
      ),
    );
  }

  void _onConnectionChanged(
    RaceConnectionChanged event,
    Emitter<RaceState> emit,
  ) {
    // A dropped socket does **not** stop your solve clock. Your time is real
    // whether or not the network agrees; room state lives in Redis, so
    // reconnecting rejoins the race rather than forfeiting it.
    emit(state.copyWith(connection: event.connection));
  }

  // --- Leaving ---------------------------------------------------------------

  Future<void> _onDismissed(
    RaceDismissed event,
    Emitter<RaceState> emit,
  ) async {
    await _stopClocks();
    emit(
      RaceState(
        phase: RacePhase.idle,
        connection: state.connection,
        mode: state.mode,
      ),
    );
  }

  Future<void> _onRematchRequested(
    RaceRematchRequested event,
    Emitter<RaceState> emit,
  ) async {
    await _stopClocks();
    add(RaceRequested(state.mode));
  }

  // --- Clocks ----------------------------------------------------------------

  Future<void> _stopSolveClock() async {
    await _solveSub?.cancel();
    _solveSub = null;
  }

  Future<void> _stopSearchClock() async {
    await _searchSub?.cancel();
    _searchSub = null;
  }

  Future<void> _stopClocks() async {
    await _stopSolveClock();
    await _stopSearchClock();
    await _stopSilenceWatchdog();
  }

  @override
  Future<void> close() async {
    await _stopClocks();
    for (final StreamSubscription<dynamic> sub in _gatewaySubs) {
      await sub.cancel();
    }
    _gatewaySubs.clear();
    _gateway.leave();
    return super.close();
  }
}
