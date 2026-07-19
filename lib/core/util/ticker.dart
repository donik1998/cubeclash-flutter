import 'dart:async';

/// Emits elapsed time since subscription.
///
/// An interface rather than a bare `Timer.periodic` for two reasons:
///
///  1. **Accuracy.** Counting ticks accumulates drift — a 30 ms timer that
///     fires late 200 times has lost real time, and a speedcubing timer that
///     is wrong by 100 ms is worthless. [RealTicker] reads a monotonic
///     [Stopwatch] on every pulse instead, so display accuracy never depends
///     on the scheduler being punctual.
///  2. **Testability.** The timer and race blocs are state machines driven by
///     time; a fake ticker lets their tests assert transitions deterministically
///     without sleeping.
abstract class Ticker {
  /// Elapsed time since subscription, pushed every [interval].
  Stream<Duration> elapsed({Duration interval});
}

class RealTicker implements Ticker {
  const RealTicker();

  /// ~60 Hz. Faster than the eye can read a hundredths digit, but the readout
  /// then never looks like it's stuttering.
  static const Duration defaultInterval = Duration(milliseconds: 16);

  @override
  Stream<Duration> elapsed({Duration interval = defaultInterval}) {
    final Stopwatch stopwatch = Stopwatch()..start();
    late StreamController<Duration> controller;
    Timer? timer;

    controller = StreamController<Duration>(
      onListen: () {
        timer = Timer.periodic(
          interval,
          (_) => controller.add(stopwatch.elapsed),
        );
      },
      onCancel: () {
        timer?.cancel();
        stopwatch.stop();
      },
    );

    return controller.stream;
  }
}
