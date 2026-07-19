import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Button hierarchy from the design system.
enum AppButtonVariant {
  /// Filled `brand/primary` — the one primary action on a screen.
  primary,

  /// `bg/surface-alt` + `border/strong`.
  secondary,

  /// Text only, no fill or border.
  ghost,
}

/// Button sizes. Both clear the 48dp minimum touch target.
enum AppButtonSize { medium, large }

/// The app's button. Radius 14 ([AppRadius.button]), token-driven, with
/// loading and disabled states.
///
/// [onPressed] of `null` **or** [isLoading] renders as disabled — a loading
/// button must not be re-tappable.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.large,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;

  /// Stretch to the available width. Off for ghost buttons by default.
  final bool expand;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double height = size == AppButtonSize.large ? 52 : 44;

    final (Color bg, Color fg, Color? border) = switch (variant) {
      AppButtonVariant.primary => (
          colors.brandPrimary,
          colors.brandOnPrimary,
          null,
        ),
      AppButtonVariant.secondary => (
          colors.bgSurfaceAlt,
          colors.textPrimary,
          colors.borderStrong,
        ),
      AppButtonVariant.ghost => (
          Colors.transparent,
          colors.brandPrimary,
          null,
        ),
    };

    // Disabled reads as "dimmed", preserving the variant's shape and hue.
    final double opacity = _enabled ? 1 : 0.45;

    final Widget content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong.copyWith(color: fg),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: Opacity(
        opacity: opacity,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: InkWell(
            onTap: _enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: border == null ? null : Border.all(color: border),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: height,
                  minWidth: expand ? double.infinity : 0,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Center(widthFactor: expand ? null : 1, child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
