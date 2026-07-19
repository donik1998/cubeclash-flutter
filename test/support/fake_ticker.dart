import 'dart:async';

import 'package:cubeclash/core/util/ticker.dart';

/// A [Ticker] whose emissions the test drives by hand.
///
/// Lets the timer/race state machines be tested at real boundaries (15.000 s vs
/// 15.001 s) instantly and deterministically, instead of sleeping and hoping.
///
/// The bloc opens a separate channel per concern (hold arming, inspection,
/// solve), so channels are addressed by creation order — [emitTo] targets one
/// precisely rather than broadcasting to all of them.
class FakeTicker implements Ticker {
  final List<StreamController<Duration>> channels =
      <StreamController<Duration>>[];

  @override
  Stream<Duration> elapsed({Duration interval = const Duration(seconds: 1)}) {
    final StreamController<Duration> controller =
        StreamController<Duration>.broadcast();
    channels.add(controller);
    return controller.stream;
  }

  /// Emits on the most recently opened channel.
  void emit(Duration value) => emitTo(channels.length - 1, value);

  void emitTo(int index, Duration value) {
    if (index < 0 || index >= channels.length) {
      throw StateError(
        'No ticker channel at index $index (${channels.length} open). '
        'The bloc probably did not subscribe where the test expected.',
      );
    }
    channels[index].add(value);
  }

  Future<void> dispose() async {
    for (final StreamController<Duration> c in channels) {
      await c.close();
    }
  }
}
