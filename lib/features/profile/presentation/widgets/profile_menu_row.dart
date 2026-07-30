import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A single row of the You · Profile menu card (Figma `47:206`): a leading
/// colored [IconTile], a label, an optional trailing value, and a chevron.
///
/// This is a *navigation* row, not the settings screen's toggle row — the
/// existing `SettingToggle`/`_SettingSwitch` is a switch and is a different
/// component (spec §4/§8). Props in, `onTap` out; it holds no state.
class ProfileMenuRow extends StatelessWidget {
  const ProfileMenuRow({
    super.key,
    required this.icon,
    required this.iconTileColor,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.trailingValue,
    this.showChevron = true,
  });

  final IconData icon;

  /// The fill behind the leading icon (Friends = brandPrimary, Share =
  /// statusSuccess, Settings = bgSurfaceAlt — all tokens, never hex).
  final Color iconTileColor;

  /// The glyph color on the tile. Defaults to `brand/on-primary`; the Settings
  /// row overrides it to `text/muted` on its neutral fill (spec §11.6).
  final Color? iconColor;

  final String label;

  /// Pre-formatted trailing value (e.g. the friend count "48"); null hides it.
  final String? trailingValue;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return InkWell(
      onTap: onTap,
      child: Padding(
        // Figma `47:206`: 14 horizontal, 12 vertical. The row's 54 height falls
        // out of the 30 tile + 12+12 padding.
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + AppSpacing.xs, // 14
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            IconTile(
              icon: icon,
              backgroundColor: iconTileColor,
              iconColor: iconColor ?? colors.brandOnPrimary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.versusName
                    .copyWith(color: colors.textPrimary),
              ),
            ),
            if (trailingValue != null) ...<Widget>[
              Text(
                trailingValue!,
                style: AppTypography.small
                    .copyWith(color: colors.textSecondary)
                    .tabular,
              ),
              const SizedBox(width: AppSpacing.sm - 2), // 6
            ],
            if (showChevron)
              Icon(
                Icons.chevron_right,
                size: 16,
                color: colors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

/// The 30×30, radius-8 colored badge holding a 16pt icon at the head of a
/// [ProfileMenuRow] (Figma `47:179`). Its own widget so the size/radius live in
/// one place and it can be reused elsewhere if a colored icon tile is needed.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.iconTile),
      ),
      child: Icon(icon, size: 16, color: iconColor),
    );
  }
}
