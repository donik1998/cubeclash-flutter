import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Chip flavours from the design system.
enum AppChipVariant {
  /// Event chip (`3×3`) — `brand/primary-soft`.
  event,

  /// `+2` — warning.
  plus2,

  /// `DNF` — danger.
  dnf,

  /// Filter / toggle chip — neutral until selected.
  filter,
}

/// Pill chip. Used for the event selector, penalty markers and list filters.
///
/// [selected] only affects [AppChipVariant.filter] and
/// [AppChipVariant.event]; penalty chips are inherently "on" when shown.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.variant = AppChipVariant.filter,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  const AppChip.plus2({super.key, this.onTap, this.selected = false})
      : label = '+2',
        variant = AppChipVariant.plus2,
        icon = null;

  const AppChip.dnf({super.key, this.onTap, this.selected = false})
      : label = 'DNF',
        variant = AppChipVariant.dnf,
        icon = null;

  final String label;
  final AppChipVariant variant;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    final (Color bg, Color fg, Color border) = switch (variant) {
      AppChipVariant.event => (
          colors.brandPrimarySoft,
          colors.brandPrimary,
          colors.brandPrimarySoft,
        ),
      AppChipVariant.plus2 => (
          colors.statusWarning.withValues(alpha: 0.16),
          colors.statusWarning,
          colors.statusWarning.withValues(alpha: 0.32),
        ),
      AppChipVariant.dnf => (
          colors.statusDanger.withValues(alpha: 0.14),
          colors.statusDanger,
          colors.statusDanger.withValues(alpha: 0.30),
        ),
      AppChipVariant.filter => selected
          ? (colors.brandPrimarySoft, colors.brandPrimary, colors.brandPrimary)
          : (colors.bgSurfaceAlt, colors.textSecondary, colors.borderSubtle),
    };

    final BorderRadius radius = BorderRadius.circular(AppRadius.pill);

    return Semantics(
      button: onTap != null,
      selected: onTap == null ? null : selected,
      child: Material(
        color: bg,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(label, style: AppTypography.label.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
