import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../util/country_names.dart';

/// One row of a leaderboard — a card: rank · avatar · name + country · time.
///
/// Matches Figma `Stats · Leaderboards` (rows `45:733` / viewer `45:775`).
///
/// [rank] and [time] are **server-owned** — this widget only displays what the
/// backend ranked. Never sort or re-rank on the client (docs → API Design:
/// "server owns is_pb, race results, ranking").
///
/// Podium accent is deliberately asymmetric to match the design: rank **1** in
/// `statusWarning`, rank **3** in `accentEnergy`, and **rank 2 is unaccented**
/// (`textSecondary`, same as every other rank) — there is no invented silver.
///
/// The country is shown as a **name** (`countryCodeToName`), falling back to
/// the raw code for an unknown one; never a flag emoji (it does not survive
/// every platform) and never a two-letter code you have to decode.
///
/// There is no avatar field in the data model — the circle is a neutral
/// placeholder, so this widget takes no image URL.
///
/// [isCurrentUser] paints the row as the pinned viewer: `brandPrimarySoft`
/// fill, `brandPrimary` border, the time in `brandPrimary`. The Leaderboards
/// screen also pins a copy of this row to the bottom when it falls outside the
/// visible range.
///
/// [nameOverride] replaces the shown name without touching the data model. The
/// pinned viewer row passes the literal `"You"` (spec §7) so the row reads
/// `"You"` regardless of the entry's `displayName` — which against a real
/// backend is the username, not `"You"`. The widget stays honest: it renders
/// exactly the name it is handed, and the override is a display-only decision
/// made at the one call site that pins the viewer.
class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({
    super.key,
    required this.rank,
    required this.displayName,
    required this.time,
    this.countryCode,
    this.isCurrentUser = false,
    this.nameOverride,
    this.onTap,
  });

  final int rank;
  final String displayName;

  /// Display-only replacement for [displayName] (e.g. `"You"` on the pinned
  /// viewer row). When null, [displayName] is shown.
  final String? nameOverride;

  /// Pre-formatted time (via `TimeText.format`).
  final String time;
  final String? countryCode;
  final bool isCurrentUser;
  final VoidCallback? onTap;

  /// Podium accent: gold for 1, energy-orange for 3. Rank 2 and everyone else
  /// share `text/secondary` — the design does not accent the runner-up.
  Color _rankColor(AppColors colors) => switch (rank) {
        1 => colors.statusWarning,
        3 => colors.accentEnergy,
        _ => colors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final String? country = countryCodeToName(countryCode) ?? countryCode;
    final String shownName = nameOverride ?? displayName;

    return Semantics(
      button: onTap != null,
      label: 'Rank $rank, $shownName, $time',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isCurrentUser ? colors.brandPrimarySoft : colors.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(
                color:
                    isCurrentUser ? colors.brandPrimary : colors.borderSubtle,
              ),
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: AppSpacing.x3, // ~30 in Figma (rk cell)
                  child: Text(
                    _formatRank(rank),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    // A four-digit rank (`1,204`) overflows the fixed cell
                    // rather than wrapping — matches the design, where the
                    // viewer's rank spills a touch past the column.
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: AppTypography.bodyStrong
                        .copyWith(color: _rankColor(colors))
                        .tabular,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const _AvatarPlaceholder(),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        shownName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong
                            .copyWith(color: colors.textPrimary),
                      ),
                      if (country != null && country.isNotEmpty)
                        Text(
                          country,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption
                              .copyWith(color: colors.textSecondary),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  time,
                  style: AppTypography.title
                      .copyWith(
                        color: isCurrentUser
                            ? colors.brandPrimary
                            : colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      )
                      .tabular,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Thousands-separated rank — the viewer's rank is `1,204` in the design.
  static String _formatRank(int rank) {
    final String digits = rank.abs().toString();
    final StringBuffer out = StringBuffer(rank < 0 ? '-' : '');
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }
}

/// The neutral avatar circle. There is no avatar in the data model, so it is a
/// solid `brand/primary-soft` fill (Figma `Ellipse`, 34pt).
class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Container(
      width: AppSpacing.x3, // ~34 in Figma (avatar ellipse)
      height: AppSpacing.x3,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.brandPrimarySoft,
      ),
    );
  }
}
