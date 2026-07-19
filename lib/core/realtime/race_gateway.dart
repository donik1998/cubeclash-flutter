import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../network/api_config.dart';

/// Wraps the Socket.IO `/race` namespace and exposes typed Dart streams the
/// Race BLoC subscribes to. Protocol: docs → `02 System Design/Real-time Race
/// Protocol` (server-authoritative; room state lives in Redis on the backend).
class RaceGateway {
  io.Socket? _socket;

  final StreamController<Map<String, dynamic>> _state =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<int> _countdown = StreamController<int>.broadcast();
  final StreamController<String> _scramble =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _result =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onState => _state.stream;
  Stream<int> get onCountdown => _countdown.stream;
  Stream<String> get onScramble => _scramble.stream;
  Stream<Map<String, dynamic>> get onResult => _result.stream;

  void connect({String? accessToken}) {
    final socket = io.io(
      '${ApiConfig.baseUrl}/race',
      io.OptionBuilder()
          .setTransports(<String>['websocket'])
          .disableAutoConnect()
          .setAuth(<String, dynamic>{'token': accessToken})
          .build(),
    );

    socket
      ..on('race:state', (dynamic d) => _state.add(_asMap(d)))
      ..on('race:countdown', (dynamic d) => _countdown.add(_asInt(d)))
      ..on('race:scramble',
          (dynamic d) => _scramble.add(_asMap(d)['scramble']?.toString() ?? ''))
      ..on('race:result', (dynamic d) => _result.add(_asMap(d)))
      ..connect();

    _socket = socket;
  }

  // Client → server events (docs/Real-time Race Protocol).
  void ready() => _socket?.emit('race:ready');
  void solveStart() => _socket?.emit('solve:start');
  void solveStop(int clientTimeMs) => _socket
      ?.emit('solve:stop', <String, dynamic>{'client_time_ms': clientTimeMs});
  void joinByCode(String code) =>
      _socket?.emit('race:join', <String, dynamic>{'code': code});

  Map<String, dynamic> _asMap(dynamic d) =>
      d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};

  int _asInt(dynamic d) => d is num ? d.toInt() : 0;

  Future<void> dispose() async {
    _socket?.dispose();
    await _state.close();
    await _countdown.close();
    await _scramble.close();
    await _result.close();
  }
}
