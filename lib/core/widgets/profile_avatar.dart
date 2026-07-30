import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// A round avatar: a brand-primary ring around an initial on a neutral fill.
///
/// **Initials only, no image, ever.** The You · Profile design (Figma `47:166`)
/// shows an empty ring, and the resolution in the spec (§11.1) removed
/// `avatar_url` from the contract entirely — there is no photo to render on any
/// client. The initial is derived from [displayName]; an empty name falls back
/// to `?`.
///
/// Shared (promoted out of the old profile page) because a ringed initial
/// avatar is generic — the profile hero uses it at 74, but a friends row or a
/// versus card could use it at any size.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.displayName,
    this.size = 74,
  });

  final String displayName;

  /// Diameter in logical pixels. The hero uses 74 (Figma `47:166`).
  final double size;

  String get _initial =>
      displayName.isEmpty ? '?' : displayName.characters.first.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    // The ring scales with the avatar so a small one is not swallowed by a
    // thick border, and a large one keeps a legible outline.
    final double ringWidth = (size / 37).clamp(1.5, 3.0);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.bgSurfaceAlt,
        border: Border.all(color: colors.brandPrimary, width: ringWidth),
      ),
      child: Text(
        _initial,
        style: AppTypography.h2.copyWith(color: colors.brandPrimary),
      ),
    );
  }
}
