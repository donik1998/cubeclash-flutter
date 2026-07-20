/// Speedcubing time formatting, in one place.
///
/// Pure Dart with no Flutter import, so both sides can use it: `TimeText` in
/// `core/widgets` renders it, and `FormatResult` in the timer domain composes
/// it into event-specific results. Neither may import the other — `core/`
/// cannot depend on `features/`, and a domain layer cannot import Flutter — so
/// the shared rule lives here rather than being written twice.
///
/// ## WCA precision (Regulation 9f)
///
///   * `9f1` — timed results **under 10 minutes** are truncated to hundredths.
///   * `9f2` — timed results **of 10 minutes or more**, and all Multi-Blind
///     times whatever their length, are truncated to **seconds**.
///
/// Always **truncates**, never rounds: a timer must not round a solve up into
/// a time the cuber did not achieve.
class TimeFormat {
  const TimeFormat._();

  /// Ten minutes — the boundary in Regulation 9f1/9f2.
  static const int secondsOnlyThresholdMs = 10 * 60 * 1000;

  /// `12.34` · `1:23.45` · `12:34` · `1:04:22`.
  ///
  /// Set [forceSecondsOnly] for Multi-Blind, which drops hundredths at any
  /// length.
  static String format(int ms, {bool forceSecondsOnly = false}) {
    final int safe = ms < 0 ? 0 : ms;
    final bool secondsOnly = forceSecondsOnly || safe >= secondsOnlyThresholdMs;

    final int totalSeconds = safe ~/ 1000;
    final int hundredths = (safe % 1000) ~/ 10;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    final String ss = seconds.toString().padLeft(2, '0');

    // An hour or more: `1:04:22`. Hundredths are already gone by 9f2, and
    // seven glyphs is as much as the hero readout can carry.
    if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';

    if (secondsOnly) return '$minutes:$ss';

    final String cs = hundredths.toString().padLeft(2, '0');
    if (minutes == 0) return '$seconds.$cs';
    return '$minutes:$ss.$cs';
  }
}
