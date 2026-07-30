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
///
/// Two orderings, because two frames disagree on which reads first:
///   * default (`valueFirst: false`) — LABEL over value, left-aligned. The
///     session/stats layout the widget was born for.
///   * `valueFirst: true` — value over label, centered, on a tighter radius.
///     The You · Profile summary tile (Figma `47:170`), "8.42 / best". Same
///     tokens, different reading order — one component, a variant, not two.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
    this.onTap,
    this.valueFirst = false,
  });

  final String label;

  /// Pre-formatted display value; `null` renders `—`.
  final String? value;

  /// Optional third line (e.g. "3 days ago").
  final String? caption;
  final Color? valueColor;
  final VoidCallback? onTap;

  /// When true, renders value-over-label, centered, on the profile-tile radius
  /// (Figma `47:170`). When false (default), label-over-value, left-aligned.
  final bool valueFirst;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return valueFirst ? _buildValueFirst(colors) : _buildLabelFirst(colors);
  }

  // --- default: LABEL over value, left-aligned -------------------------------

  Widget _buildLabelFirst(AppColors colors) {
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
          _value(colors),
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

  // --- variant: value over label, centered (Figma `47:170`) ------------------

  Widget _buildValueFirst(AppColors colors) {
    return AppCard(
      onTap: onTap,
      borderRadius: AppRadius.statTile,
      padding: const EdgeInsets.all(AppSpacing.md + AppSpacing.xs), // 14
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _value(colors),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.statLabel.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _value(AppColors colors) => Text(
        value ?? '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: valueFirst ? TextAlign.center : TextAlign.start,
        style: (valueFirst ? AppTypography.statValue : AppTypography.h2)
            .copyWith(
              color: value == null
                  ? colors.textMuted
                  : (valueColor ?? colors.textPrimary),
            )
            .tabular,
      );
}
