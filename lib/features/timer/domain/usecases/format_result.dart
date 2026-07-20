import '../../../../core/util/time_format.dart';
import '../entities/penalty.dart';
import '../entities/solve_result.dart';

/// Renders a result as the string a cuber expects to read.
///
/// Pure Dart, in the domain, because "what does this number look like" is now
/// event-dependent and therefore a rule rather than a widget detail. The
/// widgets ([TimeText] and the timer's readout) call into this.
///
/// ## WCA precision (Regulation 9f)
///
///   * `9f1` — timed results **under 10 minutes** are truncated to hundredths.
///   * `9f2` — timed results **of 10 minutes or more**, and *all* Multi-Blind
///     times whatever their length, are truncated to **seconds**.
///
/// That second rule is why [formatTime] takes `forceSecondsOnly`: a 54-minute
/// Multi-Blind attempt printed to the hundredth would be claiming a precision
/// the Regulations explicitly do not recognise, and it would also be eight
/// glyphs where five will do.
class FormatResult {
  const FormatResult();

  /// `12.34` · `1:23.45` · `12:34` · `1:04:22`. See [TimeFormat] for the
  /// precision rules and why the implementation lives in `core/util`.
  static String formatTime(int ms, {bool forceSecondsOnly = false}) =>
      TimeFormat.format(ms, forceSecondsOnly: forceSecondsOnly);

  /// A Fewest Moves single: `28`. Bare, because "28 moves" in a readout sized
  /// for a stopwatch reads as noise; the event label above it already says the
  /// unit.
  static String formatMoves(int moves) => '$moves';

  /// A Fewest Moves **mean**, which the WCA records to two decimals because
  /// the mean of three integers rarely is one — `25.67`.
  static String formatMovesMean(double moves) => moves.toStringAsFixed(2);

  /// A Multi-Blind result: `11/13 in 54:22`.
  ///
  /// The time is always seconds-only (Regulation 9f2), and the whole string is
  /// deliberately one line — it is a single result, not three.
  static String formatMultiBlind({
    required int solved,
    required int attempted,
    required int timeMs,
  }) =>
      '$solved/$attempted in ${formatTime(timeMs, forceSecondsOnly: true)}';

  /// The display string for any [result], penalty treatment included.
  static String display(SolveResult result) {
    if (result.isDnf) return 'DNF';

    switch (result.kind) {
      case ResultKind.time:
        final String base = formatTime(result.effectiveTimeMs!);
        return result.penalty == Penalty.plus2 ? '$base+' : base;
      case ResultKind.moveCount:
        return formatMoves(result.moveCount!);
      case ResultKind.multiBlind:
        return formatMultiBlind(
          solved: result.solvedCount!,
          attempted: result.attemptedCount!,
          timeMs: result.timeMs,
        );
    }
  }

  /// What a screen reader should say, since none of the above reads well as
  /// glyphs. `12.34` is not "twelve point three four".
  static String semanticsFor(SolveResult result) {
    if (result.isDnf) return 'Did not finish';
    return switch (result.kind) {
      ResultKind.time => '${display(result)} seconds',
      ResultKind.moveCount => '${result.moveCount} moves',
      ResultKind.multiBlind =>
        '${result.solvedCount} of ${result.attemptedCount} cubes solved in '
            '${formatTime(result.timeMs, forceSecondsOnly: true)}',
    };
  }
}
