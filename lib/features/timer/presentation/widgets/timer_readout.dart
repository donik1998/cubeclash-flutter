import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/penalty.dart';
import '../../domain/entities/solve_result.dart';
import '../../domain/entities/timer_preferences.dart';
import '../../domain/usecases/format_result.dart';
import '../../domain/usecases/grade_inspection.dart';
import '../bloc/timer_bloc.dart';

/// The hero numerals, plus the state dot beneath them.
///
/// What it shows depends on where the machine is:
///   * **inspecting** — the inspection countdown, colour-shifting as the WCA
///     penalty boundaries approach, so the user sees the +2 coming.
///   * **ready** — the last time, in `statusSuccess`: armed, release to go.
///   * **running / stopped / idle** — the attempt's result.
///
/// ## Why the hero scales
///
/// [AppTypography.timerHero] is 78px, sized in Figma against `0.00` — four
/// glyphs. The seventeen-event set routinely produces more: `5:23.45` is
/// seven, a Multi-Blind `58:12` plus its `11/13` is a whole phrase. At 78px
/// tabular Noto Serif anything past six glyphs overruns the content width.
///
/// So the numerals live in a [FittedBox] that scales **down** to fit and never
/// up: a 3×3 still renders at exactly the frame's 78px, and a long result
/// shrinks to fit rather than clipping or wrapping. Scaling is the right
/// failure here — a smaller readable time beats a correctly-sized one with its
/// hundredths off screen.
class TimerReadout extends StatelessWidget {
  const TimerReadout({super.key, required this.state});

  final TimerState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Scale down to the available width, never up — see the class doc.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: _numerals(context, colors),
        ),
        const SizedBox(height: AppSpacing.md),
        _StateLabel(state: state),
      ],
    );
  }

  Widget _numerals(BuildContext context, AppColors colors) {
    if (state.status == TimerStatus.inspecting) {
      return _InspectionCountdown(elapsed: state.inspectionElapsed);
    }

    final bool armed = state.status == TimerStatus.ready;
    final bool showResult = state.status == TimerStatus.stopped;

    // Once an attempt is finished, render the event's own result — a move
    // count for Fewest Moves, `11/13 in 54:22` for Multi-Blind — rather than
    // the elapsed clock, which for those two is not the result at all.
    final SolveResult? result = showResult ? state.lastSolve?.result : null;
    if (result != null && result.kind != ResultKind.time) {
      return Text(
        FormatResult.display(result),
        style: AppTypography.timerHero.copyWith(
          color: result.isDnf ? colors.statusDanger : colors.textPrimary,
        ),
        semanticsLabel: FormatResult.semanticsFor(result),
      );
    }

    final Penalty penalty = state.lastSolve?.penalty ?? Penalty.none;

    return TimeText(
      timeMs: state.elapsed.inMilliseconds,
      isPlus2: showResult && penalty == Penalty.plus2,
      isDnf: showResult && penalty == Penalty.dnf,
      style: AppTypography.timerHero,
      // Green while armed is the single most important affordance on this
      // screen: it is what tells the user the release will start the timer.
      color: armed ? colors.statusSuccess : null,
    );
  }
}

/// Inspection counts **down** from 15 — that is the number the cuber cares
/// about — then keeps counting into the penalty zones rather than freezing at
/// zero, so an overrun is legible rather than mysterious.
class _InspectionCountdown extends StatelessWidget {
  const _InspectionCountdown({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    final int remainingMs =
        GradeInspection.limit.inMilliseconds - elapsed.inMilliseconds;

    final (String text, Color color) = switch (elapsed) {
      final Duration e when e > GradeInspection.dnfLimit => (
          'DNF',
          colors.statusDanger,
        ),
      final Duration e when e > GradeInspection.limit => (
          '+2',
          colors.statusWarning,
        ),
      _ => (
          '${(remainingMs / 1000).ceil()}',
          remainingMs <= 3000 ? colors.accentEnergy : colors.textPrimary,
        ),
    };

    return Text(
      text,
      style: AppTypography.timerHero.copyWith(color: color),
      semanticsLabel: switch (text) {
        'DNF' => 'Inspection exceeded, did not finish',
        '+2' => 'Inspection exceeded, plus two',
        _ => '$text seconds of inspection left',
      },
    );
  }
}

/// Dot + label describing the current state, per the design system's timer
/// hero spec.
class _StateLabel extends StatelessWidget {
  const _StateLabel({required this.state});

  final TimerState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    final TimerStatus status = state.status;
    final (String label, Color color) = switch (status) {
      // The frame shows a green dot at idle: the timer is ready, which is a
      // more useful thing to signal than "inactive".
      // Fewest Moves has no stopwatch to hold — the label must not promise an
      // interaction the screen does not offer.
      TimerStatus.idle when state.eventSpec.isManualEntry => (
          'Record when you are done',
          colors.statusSuccess,
        ),
      TimerStatus.idle => (
          state.preferences.style == TimerStyle.hold
              ? 'Hold to start'
              : 'Tap to start',
          colors.statusSuccess,
        ),
      TimerStatus.inspecting => (
          state.preferences.style == TimerStyle.hold
              ? 'Inspecting — hold to arm'
              : 'Inspecting — tap to start',
          colors.brandPrimary,
        ),
      TimerStatus.ready => ('Release to start', colors.statusSuccess),
      TimerStatus.running => ('Solving', colors.accentEnergy),
      TimerStatus.stopped when state.awaitingManualResult => (
          'Enter your result',
          colors.brandPrimary,
        ),
      TimerStatus.stopped when state.eventSpec.isManualEntry => (
          'Recorded',
          colors.textMuted,
        ),
      TimerStatus.stopped => ('Tap to reset', colors.textMuted),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.stateLabel.copyWith(
            // The dot carries the state colour; the label stays readable.
            color: status == TimerStatus.idle ? colors.textSecondary : color,
          ),
        ),
      ],
    );
  }
}
