import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Surface container: `bg/surface`, radius 16, `border/subtle`.
///
/// The base of every panel in the app — scramble card, stat cards, list
/// sections. Pass [onTap] to make it tappable (ink stays inside the radius).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Defaults to `bg/surface`. Override for emphasis (e.g. `bg/surface-alt`).
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final BorderRadius radius = BorderRadius.circular(AppRadius.card);

    return Material(
      color: color ?? colors.bgSurface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: borderColor ?? colors.borderSubtle),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
