import 'dart:async';

import 'package:cubeclash/core/realtime/race_gateway.dart';

/// A [RaceGateway] the test drives event by event, and that records what the
/// bloc emitted back.
///
/// Deliberately *not* the demo `FakeRaceGateway` — that one runs on real
/// timers and picks its own script, which is right for a demo and wrong for a
/// test. Here every server message is sent by hand, so a race can be walked
/// into any state including the ones that are hard to reproduce live:
/// mid-solve disconnects, double submits, both players DNFing.
class ControllableRaceGateway implements RaceGateway {
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

  // --- What the bloc sent ----------------------------------------------------

  int connectCalls = 0;
  int readyCalls = 0;
  int solveStartCalls = 0;
  int leaveCalls = 0;

  /// Every time submitted, in order. Length > 1 means the idempotency guard
  /// failed.
  final List<int> submittedTimes = <int>[];
  final List<({String mode, String event})> createdRaces =
      <({String mode, String event})>[];
  final List<String> joinedCodes = <String>[];

  @override
  void connect({String? accessToken}) => connectCalls++;

  @override
  void createRace({required String mode, String event = '3x3'}) =>
      createdRaces.add((mode: mode, event: event));

  @override
  void joinByCode(String code) => joinedCodes.add(code);

  @override
  void ready() => readyCalls++;

  @override
  void solveStart() => solveStartCalls++;

  @override
  void solveStop(int clientTimeMs) => submittedTimes.add(clientTimeMs);

  @override
  void leave() => leaveCalls++;

  // --- Server messages the test sends ----------------------------------------

  /// A `race:state` snapshot. [opponent] of null means you're alone.
  void emitState({
    required String status,
    String raceId = 'race-1',
    String? code,
    bool youReady = false,
    ({String id, String name, bool ready, bool connected})? opponent,
  }) {
    _state.add(<String, dynamic>{
      'race_id': raceId,
      'status': status,
      if (code != null) 'code': code,
      'event': '3x3',
      'players': <Map<String, dynamic>>[
        <String, dynamic>{
          'user_id': 'me',
          'display_name': 'You',
          'country': 'GB',
          'ready': youReady,
          'is_me': true,
          'connected': true,
        },
        if (opponent != null)
          <String, dynamic>{
            'user_id': opponent.id,
            'display_name': opponent.name,
            'country': 'JP',
            'ready': opponent.ready,
            'is_me': false,
            'connected': opponent.connected,
          },
      ],
    });
  }

  void emitReadyUpdate(String userId, {bool ready = true}) =>
      _readyUpdate.add(<String, dynamic>{'user_id': userId, 'ready': ready});

  void emitCountdown(int n) => _countdown.add(n);

  void emitScramble(String scramble) => _scramble.add(scramble);

  void emitOpponentProgress(int runningMs) => _opponentProgress.add(runningMs);

  void emitResult({
    required String result,
    int? yourTime,
    int? oppTime,
    int? eloDelta,
    bool yourDnf = false,
    bool opponentDnf = false,
    bool opponentLeft = false,
  }) =>
      _result.add(<String, dynamic>{
        'result': result,
        'your_time': yourTime,
        'opp_time': oppTime,
        'elo_delta': eloDelta,
        'your_dnf': yourDnf,
        'opponent_dnf': opponentDnf,
        'opponent_left': opponentLeft,
      });

  void emitConnection(GatewayConnection connection) =>
      _connection.add(connection);

  @override
  Future<void> dispose() async {
    await _state.close();
    await _readyUpdate.close();
    await _countdown.close();
    await _scramble.close();
    await _opponentProgress.close();
    await _result.close();
    await _connection.close();
  }
}
