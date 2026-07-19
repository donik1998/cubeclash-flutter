import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/race_room.dart';

/// A player card in the Ready Room: avatar, name, flag, live ready state.
class RacePlayerCard extends StatelessWidget {
  const RacePlayerCard({super.key, required this.player, this.waitingLabel});

  final RacePlayer? player;

  /// Shown in place of a player while the seat is empty.
  final String? waitingLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final RacePlayer? p = player;

    if (p == null) {
      return AppCard(
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              waitingLabel ?? 'Waiting for an opponent…',
              style: AppTypography.body.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      );
    }

    final String? flag = countryCodeToFlag(p.countryCode);

    return AppCard(
      borderColor: p.ready ? colors.statusSuccess : null,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.bgSurfaceAlt,
            ),
            alignment: Alignment.center,
            child: Text(
              p.displayName.isEmpty
                  ? '?'
                  : p.displayName.characters.first.toUpperCase(),
              style: AppTypography.title.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        p.isYou ? 'You' : p.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong
                            .copyWith(color: colors.textPrimary),
                      ),
                    ),
                    if (flag != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      Text(flag, style: AppTypography.small),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  !p.connected
                      ? 'Reconnecting…'
                      : p.ready
                          ? 'Ready'
                          : 'Not ready',
                  style: AppTypography.caption.copyWith(
                    color: !p.connected
                        ? colors.statusWarning
                        : p.ready
                            ? colors.statusSuccess
                            : colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            p.ready ? Icons.check_circle : Icons.radio_button_unchecked,
            color: p.ready ? colors.statusSuccess : colors.textMuted,
          ),
        ],
      ),
    );
  }
}

/// The opponent's live progress during a race.
///
/// Shows their running clock, not a percentage — there is no "total" to be a
/// percentage of, and a bar that fills toward an unknown end is a lie. The bar
/// is a relative comparison against your own clock instead.
class OpponentProgressBar extends StatelessWidget {
  const OpponentProgressBar({
    super.key,
    required this.opponent,
    required this.yourElapsed,
    required this.reconnecting,
  });

  final RacePlayer? opponent;
  final Duration yourElapsed;
  final bool reconnecting;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final RacePlayer? p = opponent;
    if (p == null) return const SizedBox.shrink();

    final int theirMs = p.finalTimeMs ?? p.progressMs ?? 0;
    final int yourMs = yourElapsed.inMilliseconds;

    // Both clocks scaled against whichever is further along, so the two bars
    // are directly comparable.
    final int scale = (theirMs > yourMs ? theirMs : yourMs).clamp(1, 1 << 30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                p.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppTypography.caption.copyWith(color: colors.textSecondary),
              ),
            ),
            if (reconnecting)
              Text(
                'Reconnecting…',
                style:
                    AppTypography.caption.copyWith(color: colors.statusWarning),
              )
            else if (p.hasFinished)
              Text(
                'Finished ${TimeText.format(p.finalTimeMs!)}',
                style: AppTypography.caption
                    .copyWith(color: colors.statusSuccess)
                    .tabular,
              )
            else
              Text(
                TimeText.format(theirMs),
                style: AppTypography.caption
                    .copyWith(color: colors.textSecondary)
                    .tabular,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _Bar(
          fraction: theirMs / scale,
          color: reconnecting ? colors.statusWarning : colors.textMuted,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'You',
          style: AppTypography.caption.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Bar(fraction: yourMs / scale, color: colors.brandPrimary),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: fraction.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: context.colors.bgSurfaceAlt,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
