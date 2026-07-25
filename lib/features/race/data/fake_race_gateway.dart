import 'dart:async';
import 'dart:math';

import '../../../core/realtime/race_gateway.dart';
import '../../timer/domain/entities/wca_event.dart';
import '../../timer/domain/usecases/generate_scramble.dart';

/// A [RaceGateway] that plays the part of the server **and** an opponent.
///
/// The backend doesn't exist yet, and a race is the one feature that cannot be
/// faked with a static repository — it is a conversation over time. So this
/// scripts the whole lifecycle: matchmaking waits a beat, an opponent appears,
/// readies up, the countdown runs, a scramble is revealed, the opponent's
/// progress ticks up, and the server decides a winner.
///
/// It is deliberately a **peer of the socket implementation, not a shortcut**:
/// it emits the same events, in the same order, with the same payload shape, so
/// `RaceBloc` cannot tell the difference. That is what makes it worth having —
/// the bloc is exercised against a real protocol conversation, not a stub.
///
/// The opponent's time is drawn from a plausible distribution, so you lose
/// sometimes. A fake that always lets you win would hide every bug in the
/// losing path.
class FakeRaceGateway implements RaceGateway {
  FakeRaceGateway({
    Random? random,
    GenerateScramble? generateScramble,
    double? opponentDropChance,
  })  : _random = random ?? Random(),
        _generateScramble = generateScramble ?? GenerateScramble(),
        _dropChance = opponentDropChance ?? 0.35;

  final Random _random;
  final GenerateScramble _generateScramble;

  /// How often the opponent's connection blips mid-solve. Real races drop
  /// sometimes, and the reconnect path is one of the more interesting things
  /// the bloc handles, so the demo shows it off roughly a third of the time.
  /// Injectable so a test can force it on (1.0) or off (0.0).
  final double _dropChance;

  /// The event this room is racing. Set by [createRace]; a joined room learns
  /// it from the host's `race:state`, which the fake mirrors back.
  String _event = '3x3';

  final StreamController<Map<String, dynamic>> _state =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _readyUpdate =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<int> _countdown = StreamController<int>.broadcast();
  final StreamController<String> _scramble =
      StreamController<String>.broadcast();
  final StreamController<int> _opponentProgress =
      StreamController<int>.broadcast();
  final StreamController<Map<String, dynamic>> _result =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<GatewayConnection> _connection =
      StreamController<GatewayConnection>.broadcast();

  @override
  Stream<Map<String, dynamic>> get onState => _state.stream;
  @override
  Stream<Map<String, dynamic>> get onReadyUpdate => _readyUpdate.stream;
  @override
  Stream<int> get onCountdown => _countdown.stream;
  @override
  Stream<String> get onScramble => _scramble.stream;
  @override
  Stream<int> get onOpponentProgress => _opponentProgress.stream;
  @override
  Stream<Map<String, dynamic>> get onResult => _result.stream;
  @override
  Stream<GatewayConnection> get onConnection => _connection.stream;

  final List<Timer> _timers = <Timer>[];
  bool _disposed = false;

  String _raceId = '';
  String? _code;
  int _opponentTargetMs = 0;
  int _yourTimeMs = 0;
  bool _youSubmitted = false;
  bool _opponentSubmitted = false;
  bool _settled = false;

  /// Whether the opponent is currently connected — flipped false for a beat
  /// during the mid-solve blip, then true again on reconnect.
  bool _oppConnected = true;

  static const String _youId = 'me';

  /// A roster to draw from, so a run of races isn't the same face every time.
  /// One is picked per race in [_reset].
  static const List<_Opponent> _roster = <_Opponent>[
    _Opponent('bot-1', 'Kenji Sato', 'JP'),
    _Opponent('bot-2', 'Lucia Moreno', 'ES'),
    _Opponent('bot-3', 'Aiden Walsh', 'IE'),
    _Opponent('bot-4', 'Fatima Zahra', 'MA'),
    _Opponent('bot-5', 'Viktor Petrov', 'BG'),
    _Opponent('bot-6', 'Mei Lin', 'CN'),
    _Opponent('bot-7', 'Daniel Okafor', 'NG'),
    _Opponent('bot-8', 'Sofia Almeida', 'BR'),
  ];

  late _Opponent _opponent = _roster.first;
  String get _opponentId => _opponent.id;
  String get _opponentName => _opponent.name;
  String get _opponentCountry => _opponent.country;

  void _later(Duration delay, void Function() action) {
    if (_disposed) return;
    _timers.add(Timer(delay, () {
      if (!_disposed) action();
    }));
  }

  @override
  void connect({String? accessToken}) {
    _connection.add(GatewayConnection.connecting);
    _later(const Duration(milliseconds: 200), () {
      _connection.add(GatewayConnection.connected);
    });
  }

  @override
  void createRace({required String mode, String event = '3x3'}) {
    _reset();
    _event = event;
    _raceId = 'race-${_random.nextInt(1 << 30)}';
    _code = mode == 'private' ? _inviteCode() : null;

    // Room opens empty — you, waiting.
    _emitState(status: 'waiting', withOpponent: false);

    // Quick match pairs after a realistic wait; a private room waits for a
    // human, so the fake opponent joins after a longer, "someone used your
    // code" delay.
    final Duration wait = mode == 'private'
        ? const Duration(seconds: 6)
        : Duration(milliseconds: 1800 + _random.nextInt(2600));

    _later(wait, () {
      _emitState(status: 'ready-check', withOpponent: true);
      // The opponent readies up a moment after appearing.
      _later(Duration(milliseconds: 900 + _random.nextInt(1400)), () {
        _readyUpdate.add(<String, dynamic>{
          'user_id': _opponentId,
          'ready': true,
        });
        _emitState(status: 'ready-check', withOpponent: true, oppReady: true);
        _maybeStartCountdown();
      });
    });
  }

  /// A believable solve time for [event]. A 2×2 opponent finishing in
  /// fourteen seconds would break the demo as thoroughly as a 5×5 one
  /// finishing in nine.
  int _plausibleTimeMs(WcaEvent event) {
    // The two non-cube events that are raceable have no [cubeSize] to switch on.
    switch (event.id) {
      case 'clock':
        return 6000 + _random.nextInt(6000);
      case 'pyraminx':
        return 4000 + _random.nextInt(5000);
      case 'skewb':
        return 4500 + _random.nextInt(5000);
      case 'square-1':
        return 9000 + _random.nextInt(8000);
      case 'megaminx':
        return 45000 + _random.nextInt(35000);
    }
    return switch (event.cubeSize ?? 3) {
      2 => 3000 + _random.nextInt(4000),
      3 => 9000 + _random.nextInt(9000),
      4 => 38000 + _random.nextInt(30000),
      5 => 70000 + _random.nextInt(50000),
      6 => 140000 + _random.nextInt(80000),
      _ => 210000 + _random.nextInt(120000),
    };
  }

  @override
  void joinByCode(String code) {
    _reset();
    _raceId = 'race-${_random.nextInt(1 << 30)}';
    _code = code;

    // Joining an existing room drops you straight into ready-check.
    _later(const Duration(milliseconds: 600), () {
      _emitState(status: 'ready-check', withOpponent: true);
      _later(Duration(milliseconds: 800 + _random.nextInt(1200)), () {
        _readyUpdate.add(<String, dynamic>{
          'user_id': _opponentId,
          'ready': true,
        });
        _emitState(status: 'ready-check', withOpponent: true, oppReady: true);
        _maybeStartCountdown();
      });
    });
  }

  bool _youReady = false;
  bool _oppReady = false;

  @override
  void ready() {
    _youReady = true;
    _readyUpdate.add(<String, dynamic>{'user_id': _youId, 'ready': true});
    _emitState(
      status: 'ready-check',
      withOpponent: true,
      youReady: true,
      oppReady: _oppReady,
    );
    _maybeStartCountdown();
  }

  void _maybeStartCountdown() {
    if (!_youReady || !_oppReady || _settled) return;
    _startCountdown();
  }

  void _startCountdown() {
    _emitState(
        status: 'countdown',
        withOpponent: true,
        youReady: true,
        oppReady: true);

    // 3 · 2 · 1 · GO(0), one per second.
    for (int n = 3; n >= 0; n--) {
      _later(Duration(seconds: 3 - n), () => _countdown.add(n));
    }

    // The scramble is revealed on GO, to both at once.
    _later(const Duration(seconds: 3), () {
      _scramble.add(
        _generateScramble.scrambleFor(WcaEvent.fromId(_event)).text,
      );
      _emitState(
          status: 'racing', withOpponent: true, youReady: true, oppReady: true);
      _runOpponent();
    });
  }

  /// The opponent solves in a plausible time, occasionally DNFing, with their
  /// running clock reported like the real `race:opponent_progress`.
  ///
  /// **Both the pace and the cadence scale with the event.** A 3×3 race is
  /// over in ten seconds and a 10 Hz opponent bar is what makes it feel live;
  /// a 5×5 race is two minutes, where the same rate would be 1,200 messages
  /// to animate a bar nobody is watching that closely. So long-form events
  /// report at 4 Hz — still smooth at the scale the bar moves, at a third of
  /// the traffic.
  void _runOpponent() {
    final WcaEvent event = WcaEvent.fromId(_event);
    _opponentTargetMs = _plausibleTimeMs(event);
    final bool opponentDnfs = _random.nextDouble() < 0.08;

    _maybeScheduleDrop();

    final Duration tick = event.isLongForm || (event.cubeSize ?? 3) >= 5
        ? const Duration(milliseconds: 250)
        : const Duration(milliseconds: 100);
    int elapsed = 0;

    final Timer timer = Timer.periodic(tick, (Timer t) {
      if (_disposed || _settled) {
        t.cancel();
        return;
      }
      // A disconnected opponent's progress stops arriving — their bar freezes
      // where it was and resumes on reconnect, which is exactly the state the
      // race screen's connection indicator exists to show.
      if (!_oppConnected) return;

      elapsed += tick.inMilliseconds;
      _opponentProgress.add(elapsed);

      if (elapsed >= _opponentTargetMs) {
        t.cancel();
        _opponentSubmitted = true;
        if (opponentDnfs) _opponentTargetMs = -1; // sentinel: DNF
        _maybeSettle();
      }
    });
    _timers.add(timer);
  }

  /// Occasionally drops the opponent's connection partway through their solve
  /// and restores it a beat later — the reconnect path, demoed live. Never
  /// fires once a race has settled.
  void _maybeScheduleDrop() {
    if (_random.nextDouble() >= _dropChance) return;

    // Somewhere in the first half of the solve, so the reconnect still lands
    // before they finish.
    final int at =
        (_opponentTargetMs * (0.2 + _random.nextDouble() * 0.3)).round();
    _later(Duration(milliseconds: at), () {
      if (_settled) return;
      _oppConnected = false;
      _emitState(
          status: 'racing', withOpponent: true, youReady: true, oppReady: true);

      _later(const Duration(milliseconds: 1300), () {
        if (_settled) return;
        _oppConnected = true;
        _emitState(
            status: 'racing',
            withOpponent: true,
            youReady: true,
            oppReady: true);
      });
    });
  }

  @override
  void solveStart() {
    // The server stamps its own receipt time; nothing to echo back.
  }

  @override
  void solveStop(int clientTimeMs) {
    // Idempotent: the server ignores a duplicate submit once a participant is
    // marked submitted (docs → Real-time Race Protocol § Resilience). The bloc
    // guards this too; both layers must, since either can be the one that
    // double-fires.
    if (_youSubmitted) return;
    _youSubmitted = true;
    _yourTimeMs = clientTimeMs;
    _maybeSettle();
  }

  void _maybeSettle() {
    if (_settled || !_youSubmitted || !_opponentSubmitted) return;
    _settled = true;

    final bool oppDnf = _opponentTargetMs < 0;
    // The *server* decides. Rendered as-is by the client.
    final bool youWin = oppDnf || _yourTimeMs < _opponentTargetMs;

    _later(const Duration(milliseconds: 400), () {
      _emitState(status: 'settled', withOpponent: true);
      _result.add(<String, dynamic>{
        'result': youWin ? 'win' : 'loss',
        'your_time': _yourTimeMs,
        'opp_time': oppDnf ? null : _opponentTargetMs,
        'opponent_dnf': oppDnf,
        'elo_delta':
            youWin ? 12 + _random.nextInt(12) : -(8 + _random.nextInt(10)),
      });
    });
  }

  @override
  void leave() {
    _cancelTimers();
    _connection.add(GatewayConnection.disconnected);
  }

  void _reset() {
    _cancelTimers();
    _opponent = _roster[_random.nextInt(_roster.length)];
    _youReady = false;
    _oppReady = false;
    _youSubmitted = false;
    _opponentSubmitted = false;
    _settled = false;
    _oppConnected = true;
    _yourTimeMs = 0;
  }

  void _cancelTimers() {
    for (final Timer t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _emitState({
    required String status,
    required bool withOpponent,
    bool youReady = false,
    bool oppReady = false,
  }) {
    _youReady = youReady || _youReady;
    _oppReady = oppReady || _oppReady;

    _state.add(<String, dynamic>{
      'race_id': _raceId,
      'status': status,
      if (_code != null) 'code': _code,
      'event': _event,
      'players': <Map<String, dynamic>>[
        <String, dynamic>{
          'user_id': _youId,
          'display_name': 'You',
          'country': 'GB',
          'ready': _youReady,
          'is_me': true,
          'connected': true,
        },
        if (withOpponent)
          <String, dynamic>{
            'user_id': _opponentId,
            'display_name': _opponentName,
            'country': _opponentCountry,
            'ready': _oppReady,
            'is_me': false,
            'connected': _oppConnected,
          },
      ],
    });
  }

  /// Six uppercase letters, ambiguous glyphs removed — an invite code gets read
  /// aloud and typed by hand.
  String _inviteCode() {
    const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return String.fromCharCodes(<int>[
      for (int i = 0; i < 6; i++)
        alphabet.codeUnitAt(_random.nextInt(alphabet.length)),
    ]);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _cancelTimers();
    await _state.close();
    await _readyUpdate.close();
    await _countdown.close();
    await _scramble.close();
    await _opponentProgress.close();
    await _result.close();
    await _connection.close();
  }
}

/// One scripted opponent identity, drawn from [FakeRaceGateway._roster].
class _Opponent {
  const _Opponent(this.id, this.name, this.country);

  final String id;
  final String name;
  final String country;
}
