import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/penalty.dart';
import '../../domain/entities/solve.dart';

/// The last few solves, newest first, with the running session averages under
/// them.
///
/// Deliberately compact: it is a glance, not a list. The full list lives on
/// Session & History.
class LastSolvesStrip extends StatelessWidget {
  const LastSolvesStrip({
    super.key,
    required this.solves,
    required this.ao5,
    required this.ao12,
    this.onSolveTap,
    this.onSeeAll,
    this.maxVisible = 5,
  });

  /// Session solves, oldest first (as the repository streams them).
  final List<Solve> solves;
  final int? ao5;
  final int? ao12;
  final void Function(Solve solve)? onSolveTap;
  final VoidCallback? onSeeAll;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    if (solves.isEmpty) {
      return Text(
        'Your session starts with your first solve.',
        textAlign: TextAlign.center,
        style: AppTypography.small.copyWith(color: colors.textMuted),
      );
    }

    final List<Solve> recent = solves.reversed.take(maxVisible).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final Solve solve = recent[index];
              return _SolvePill(
                solve: solve,
                onTap: onSolveTap == null ? null : () => onSolveTap!(solve),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _Average(label: 'Ao5', value: ao5),
            const SizedBox(width: AppSpacing.xl),
            _Average(label: 'Ao12', value: ao12),
            if (onSeeAll != null) ...<Widget>[
              const SizedBox(width: AppSpacing.xl),
              AppButton.ghost(label: 'History', onPressed: onSeeAll),
            ],
          ],
        ),
      ],
    );
  }
}

class _SolvePill extends StatelessWidget {
  const _SolvePill({required this.solve, required this.onTap});

  final Solve solve;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Material(
      color: colors.bgSurfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Center(
            child: TimeText(
              timeMs: solve.timeMs,
              isPlus2: solve.penalty == Penalty.plus2,
              isDnf: solve.isDnf,
              style: AppTypography.label,
            ),
          ),
        ),
      ),
    );
  }
}

class _Average extends StatelessWidget {
  const _Average({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: AppTypography.caption.copyWith(color: colors.textMuted),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          // `—` rather than 0.00: fewer than 5 solves means "not yet", not
          // "instant".
          value == null ? '—' : TimeText.format(value!),
          style: AppTypography.label
              .copyWith(
                color: value == null ? colors.textMuted : colors.textPrimary,
              )
              .tabular,
        ),
      ],
    );
  }
}
