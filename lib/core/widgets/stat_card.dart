import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// Big value over a small label — Best / Ao5 / Ao12 / Ao100.
///
/// [value] is pre-formatted by the caller (usually via `TimeText.display`) so
/// this widget stays presentation-only and never formats domain data itself.
/// A `null` [value] renders the em-dash placeholder for "not enough solves".
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
    this.onTap,
  });

  final String label;

  /// Pre-formatted display value; `null` renders `—`.
  final String? value;

  /// Optional third line (e.g. "3 days ago").
  final String? caption;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppTypography.overline.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h2
                .copyWith(
                  color: value == null
                      ? colors.textMuted
                      : (valueColor ?? colors.textPrimary),
                )
                .tabular,
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
