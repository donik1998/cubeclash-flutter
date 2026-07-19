import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'country_flag.dart';

/// One row of a leaderboard: rank · avatar · name + country · time.
///
/// [rank] and [time] are **server-owned** — this widget only displays what the
/// backend ranked. Never sort or re-rank on the client (docs → API Design:
/// "server owns is_pb, race results, ranking").
///
/// [isCurrentUser] highlights the row; the Leaderboards screen also pins a
/// copy of the current user's row to the bottom when it falls outside the
/// visible range.
class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({
    super.key,
    required this.rank,
    required this.displayName,
    required this.time,
    this.countryCode,
    this.avatarUrl,
    this.isCurrentUser = false,
    this.onTap,
  });

  final int rank;
  final String displayName;

  /// Pre-formatted time (via `TimeText.display`).
  final String time;
  final String? countryCode;
  final String? avatarUrl;
  final bool isCurrentUser;
  final VoidCallback? onTap;

  /// Medal colours for the podium; everyone else gets muted text.
  Color? _medalColor() => switch (rank) {
        1 => const Color(0xFFD4AF37), // gold
        2 => const Color(0xFFA8B0BA), // silver
        3 => const Color(0xFFB87333), // bronze
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Color? medal = _medalColor();
    final String? flag = countryCodeToFlag(countryCode);

    return Semantics(
      button: onTap != null,
      label: 'Rank $rank, $displayName, $time',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isCurrentUser ? colors.brandPrimarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 32,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyStrong
                      .copyWith(color: medal ?? colors.textMuted)
                      .tabular,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _Avatar(
                displayName: displayName,
                avatarUrl: avatarUrl,
                medal: medal,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          color: colors.textPrimary,
                          fontWeight:
                              isCurrentUser ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (flag != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      Text(flag, style: AppTypography.small),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                time,
                style: AppTypography.bodyStrong
                    .copyWith(color: colors.textPrimary)
                    .tabular,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.displayName,
    required this.avatarUrl,
    required this.medal,
  });

  final String displayName;
  final String? avatarUrl;
  final Color? medal;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final String initial =
        displayName.isEmpty ? '?' : displayName.characters.first.toUpperCase();

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.bgSurfaceAlt,
        border: medal == null ? null : Border.all(color: medal!, width: 2),
        image: avatarUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(avatarUrl!),
                fit: BoxFit.cover,
              ),
      ),
      alignment: Alignment.center,
      child: avatarUrl != null
          ? null
          : Text(
              initial,
              style: AppTypography.label.copyWith(color: colors.textSecondary),
            ),
    );
  }
}
