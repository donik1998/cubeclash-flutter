import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/penalty.dart';
import '../../domain/entities/timer_preferences.dart';
import '../../domain/usecases/grade_inspection.dart';
import '../bloc/timer_bloc.dart';

/// The hero numerals, plus the state dot beneath them.
///
/// What it shows depends on where the machine is:
///   * **inspecting** — the inspection countdown, colour-shifting as the WCA
///     penalty boundaries approach, so the user sees the +2 coming.
///   * **ready** — the last time, in `statusSuccess`: armed, release to go.
///   * **running / stopped / idle** — the solve time.
class TimerReadout extends StatelessWidget {
  const TimerReadout({super.key, required this.state});

  final TimerState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _numerals(context, colors),
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
    final Penalty penalty = state.lastSolve?.penalty ?? Penalty.none;
    final bool showPenalty = state.status == TimerStatus.stopped;

    return TimeText(
      timeMs: state.elapsed.inMilliseconds,
      isPlus2: showPenalty && penalty == Penalty.plus2,
      isDnf: showPenalty && penalty == Penalty.dnf,
      style: AppTypography.display,
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
      style: AppTypography.display.copyWith(color: color),
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

    final (String label, Color color) = switch (state.status) {
      TimerStatus.idle => (
          state.preferences.style == TimerStyle.hold
              ? 'Hold to start'
              : 'Tap to start',
          colors.textMuted,
        ),
      TimerStatus.inspecting => (
          state.preferences.style == TimerStyle.hold
              ? 'Inspecting — hold to arm'
              : 'Inspecting — tap to start',
          colors.brandPrimary,
        ),
      TimerStatus.ready => ('Release to start', colors.statusSuccess),
      TimerStatus.running => ('Solving', colors.accentEnergy),
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
        Text(label, style: AppTypography.label.copyWith(color: color)),
      ],
    );
  }
}
