import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/leaderboard_entry.dart';

/// The head-to-head record against one other player.
///
/// Extracted from the Player Profile page so the null-vs-0-0 distinction can be
/// tested directly: those two states look similar and mean opposite things, and
/// a private widget inside a page can only be exercised through a cubit and a
/// fake repository.
class HeadToHeadCard extends StatelessWidget {
  const HeadToHeadCard({
    super.key,
    required this.record,
    required this.opponentName,
  });

  final HeadToHead? record;
  final String opponentName;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    // Null and 0-0 are different states and the server distinguishes them:
    // `head_to_head` is null when the two have never raced, and an object when
    // they have. A present {0, 0} therefore means "raced, nobody has won" --
    // collapsing it into "never raced" would erase a real shared history.
    if (record == null) {
      return AppCard(
        child: Column(
          children: <Widget>[
            Text(
              "You haven't raced $opponentName yet",
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    final HeadToHead h2h = record!;

    return AppCard(
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _Tally(
                value: h2h.wins,
                label: 'You',
                color: colors.statusSuccess,
              ),
              Text(
                '–',
                style: AppTypography.h2.copyWith(color: colors.textMuted),
              ),
              _Tally(
                value: h2h.losses,
                label: opponentName,
                color: colors.statusDanger,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            h2h.decided == 0
                ? 'No decided races yet'
                : '${h2h.decided} decided race'
                    '${h2h.decided == 1 ? '' : 's'}',
            style: AppTypography.caption.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          '$value',
          style: AppTypography.h1.copyWith(color: color).tabular,
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: 100,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style:
                AppTypography.caption.copyWith(color: context.colors.textMuted),
          ),
        ),
      ],
    );
  }
}
