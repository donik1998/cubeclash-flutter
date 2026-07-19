import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../network/api_config.dart';

/// Whether the realtime transport is currently up.
enum GatewayConnection { connecting, connected, disconnected }

/// The `/race` realtime port.
///
/// An interface rather than a bare class so the Race Bloc can be driven by a
/// scripted [FakeRaceGateway] in tests and in the no-backend demo. Protocol:
/// docs → `02 System Design/Real-time Race Protocol`. The server is
/// authoritative throughout — the client emits intent and renders state.
///
/// Payloads arrive as raw maps. Decoding into domain entities is the data
/// layer's job (`RaceRoomDto`), not this port's — that keeps the socket
/// plumbing free of anything it would have to change when the schema moves.
abstract class RaceGateway {
  /// Full room state — `race:state {status, players}`.
  Stream<Map<String, dynamic>> get onState;

  /// One player's ready flag flipped — `race:ready_update {user_id, ready}`.
  Stream<Map<String, dynamic>> get onReadyUpdate;

  /// `race:countdown {n}`. `0` means GO.
  Stream<int> get onCountdown;

  /// `race:scramble {scramble}` — revealed to both players at the same instant.
  Stream<String> get onScramble;

  /// `race:opponent_progress {running_ms}`.
  Stream<int> get onOpponentProgress;

  /// `race:result {result, your_time, opp_time}`.
  Stream<Map<String, dynamic>> get onResult;

  /// Transport health. The Live Race screen surfaces this — a frozen opponent
  /// bar and a dropped socket look identical otherwise.
  Stream<GatewayConnection> get onConnection;

  void connect({String? accessToken});

  /// `race:create` — quick match enqueues; private returns an invite code.
  void createRace({required String mode, String event});

  void joinByCode(String code);
  void ready();
  void solveStart();
  void solveStop(int clientTimeMs);

  /// Leave the room and drop the socket.
  void leave();

  Future<void> dispose();
}

/// The real gateway, over Socket.IO.
class SocketRaceGateway implements RaceGateway {
  io.Socket? _socket;

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

  @override
  void connect({String? accessToken}) {
    _connection.add(GatewayConnection.connecting);

    final io.Socket socket = io.io(
      '${ApiConfig.baseUrl}/race',
      io.OptionBuilder()
          .setTransports(<String>['websocket'])
          .disableAutoConnect()
          // The protocol doc never states how the JWT reaches the socket;
          // the handshake `auth` payload is the Socket.IO convention.
          .setAuth(<String, dynamic>{'token': accessToken})
          .build(),
    );

    socket
      ..on('race:state', (dynamic d) => _state.add(_asMap(d)))
      ..on('race:ready_update', (dynamic d) => _readyUpdate.add(_asMap(d)))
      ..on('race:countdown', (dynamic d) => _countdown.add(_countdownOf(d)))
      ..on(
        'race:scramble',
        (dynamic d) => _scramble.add(_asMap(d)['scramble']?.toString() ?? ''),
      )
      ..on(
        'race:opponent_progress',
        (dynamic d) => _opponentProgress.add(
          _intOf(_asMap(d)['running_ms']),
        ),
      )
      ..on('race:result', (dynamic d) => _result.add(_asMap(d)))
      ..onConnect((_) => _connection.add(GatewayConnection.connected))
      ..onDisconnect((_) => _connection.add(GatewayConnection.disconnected))
      ..onConnectError((_) => _connection.add(GatewayConnection.disconnected))
      ..connect();

    _socket = socket;
  }

  @override
  void createRace({required String mode, String event = '3x3'}) =>
      _socket?.emit('race:create', <String, dynamic>{
        'mode': mode,
        'event': event,
      });

  @override
  void joinByCode(String code) =>
      _socket?.emit('race:join', <String, dynamic>{'code': code});

  @override
  void ready() => _socket?.emit('race:ready');

  @override
  void solveStart() => _socket?.emit('solve:start');

  @override
  void solveStop(int clientTimeMs) => _socket
      ?.emit('solve:stop', <String, dynamic>{'client_time_ms': clientTimeMs});

  @override
  void leave() {
    _socket?.emit('race:leave');
    _socket?.disconnect();
  }

  Map<String, dynamic> _asMap(dynamic d) =>
      d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};

  int _intOf(dynamic d) => d is num ? d.toInt() : 0;

  /// The doc shows `race:countdown {n}` but leaves the envelope loose —
  /// tolerate both a bare number and `{n: 3}`.
  int _countdownOf(dynamic d) {
    if (d is num) return d.toInt();
    return _intOf(_asMap(d)['n']);
  }

  @override
  Future<void> dispose() async {
    _socket?.dispose();
    await _state.close();
    await _readyUpdate.close();
    await _countdown.close();
    await _scramble.close();
    await _opponentProgress.close();
    await _result.close();
    await _connection.close();
  }
}
