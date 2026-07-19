import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Renders a solve time with its penalty applied.
///
/// Deliberately knows nothing about the timer feature's `Penalty` entity —
/// `core/` must not depend on `features/`, so callers pass the two booleans and
/// the feature layer does the mapping. See `SolveTimeText` in the timer feature.
///
/// Formatting follows speedcubing convention:
///   * under a minute → `12.34`
///   * a minute or over → `1:23.45`
///   * hundredths are **truncated, not rounded** — a timer never rounds a solve
///     up into a time the cuber did not achieve.
///   * `+2` shows the penalised time with a trailing `+` (`12.34+`)
///   * a DNF shows `DNF`
///
/// Always uses tabular figures so a live-updating readout does not jitter.
class TimeText extends StatelessWidget {
  const TimeText({
    super.key,
    required this.timeMs,
    this.isPlus2 = false,
    this.isDnf = false,
    this.style,
    this.color,
  });

  /// Raw recorded time in milliseconds, **before** the +2 is applied.
  final int timeMs;
  final bool isPlus2;
  final bool isDnf;
  final TextStyle? style;
  final Color? color;

  /// `ms` → `12.34` / `1:23.45`. Hundredths truncated.
  static String format(int ms) {
    final int safe = ms < 0 ? 0 : ms;
    final int totalSeconds = safe ~/ 1000;
    final int hundredths = (safe % 1000) ~/ 10;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    final String cs = hundredths.toString().padLeft(2, '0');

    if (minutes == 0) return '$seconds.$cs';
    return '$minutes:${seconds.toString().padLeft(2, '0')}.$cs';
  }

  /// The full display string including penalty treatment.
  static String display({
    required int timeMs,
    bool isPlus2 = false,
    bool isDnf = false,
  }) {
    if (isDnf) return 'DNF';
    if (isPlus2) return '${format(timeMs + 2000)}+';
    return format(timeMs);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final TextStyle base = style ?? AppTypography.bodyStrong;

    final Color resolved = color ??
        (isDnf
            ? colors.statusDanger
            : isPlus2
                ? colors.statusWarning
                : colors.textPrimary);

    final String text = display(timeMs: timeMs, isPlus2: isPlus2, isDnf: isDnf);

    return Text(
      text,
      style: base.copyWith(color: resolved).tabular,
      // Screen readers should hear "twelve point three four seconds", not the
      // glyph soup.
      semanticsLabel: isDnf ? 'Did not finish' : '$text seconds',
    );
  }
}
