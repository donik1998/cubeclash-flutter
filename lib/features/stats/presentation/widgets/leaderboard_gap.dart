import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// The `· · ·` separator between the top page and the pinned viewer row
/// (Figma `div` `45:773`). Signals "the leaderboard continues, your row is
/// somewhere below" without drawing a full divider.
class LeaderboardGap extends StatelessWidget {
  const LeaderboardGap({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Semantics(
      label: 'More ranks between',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: Text(
            '· · ·',
            style: AppTypography.title.copyWith(color: colors.textMuted),
          ),
        ),
      ),
    );
  }
}
