import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

/// The scramble to apply before the next solve.
///
/// Monospaced-feeling layout matters more than it looks: a cuber reads this in
/// chunks while turning, so the moves are spaced generously and wrap on move
/// boundaries rather than mid-token.
class ScrambleCard extends StatelessWidget {
  const ScrambleCard({
    super.key,
    required this.scramble,
    required this.onNewScramble,
  });

  final String scramble;
  final VoidCallback onNewScramble;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'SCRAMBLE',
                style: AppTypography.overline.copyWith(color: colors.textMuted),
              ),
              const Spacer(),
              // 40dp icon + the card's 16 padding clears the 48dp target.
              IconButton(
                onPressed: onNewScramble,
                icon: const Icon(Icons.refresh, size: 20),
                color: colors.brandPrimary,
                visualDensity: VisualDensity.compact,
                tooltip: 'New scramble',
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            scramble,
            style: AppTypography.small.copyWith(
              color: colors.textPrimary,
              // Moves read as discrete tokens, not a word.
              letterSpacing: 0.6,
              height: 1.6,
            ),
            semanticsLabel: 'Scramble: ${scramble.split(' ').join(', ')}',
          ),
        ],
      ),
    );
  }
}
