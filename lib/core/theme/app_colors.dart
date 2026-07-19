import 'package:flutter/material.dart';

/// Semantic color tokens from the CubeClash design system.
///
/// Values mirror Obsidian → `05 Design/Design System` (Light / Dark modes).
/// Read them off the current theme via `context.colors`.
@immutable
class AppColors {
  const AppColors({
    required this.bgCanvas,
    required this.bgSurface,
    required this.bgSurfaceAlt,
    required this.borderSubtle,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brandPrimary,
    required this.brandOnPrimary,
    required this.brandPrimarySoft,
    required this.statusSuccess,
    required this.statusDanger,
    required this.statusWarning,
    required this.accentEnergy,
    required this.segTrack,
    required this.segThumb,
    required this.brightness,
  });

  final Color bgCanvas;
  final Color bgSurface;
  final Color bgSurfaceAlt;
  final Color borderSubtle;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color brandPrimary;
  final Color brandOnPrimary;
  final Color brandPrimarySoft;
  final Color statusSuccess;
  final Color statusDanger;
  final Color statusWarning;
  final Color accentEnergy;
  final Color segTrack;
  final Color segThumb;
  final Brightness brightness;

  static const AppColors light = AppColors(
    bgCanvas: Color(0xFFF5F6F8),
    bgSurface: Color(0xFFFFFFFF),
    bgSurfaceAlt: Color(0xFFEEF0F4),
    borderSubtle: Color(0xFFE4E7EC),
    borderStrong: Color(0xFFCBD1DC),
    textPrimary: Color(0xFF14171D),
    textSecondary: Color(0xFF5B6472),
    textMuted: Color(0xFF9AA3B2),
    brandPrimary: Color(0xFF2E6BFF),
    brandOnPrimary: Color(0xFFFFFFFF),
    brandPrimarySoft: Color(0xFFE7EEFF),
    statusSuccess: Color(0xFF12B76A),
    statusDanger: Color(0xFFE23744),
    statusWarning: Color(0xFFF5B800),
    accentEnergy: Color(0xFFFF6A2C),
    segTrack: Color(0xFFEAEDF2),
    segThumb: Color(0xFFFFFFFF),
    brightness: Brightness.light,
  );

  static const AppColors dark = AppColors(
    bgCanvas: Color(0xFF0C0E12),
    bgSurface: Color(0xFF16191F),
    bgSurfaceAlt: Color(0xFF1E222A),
    borderSubtle: Color(0xFF262B33),
    borderStrong: Color(0xFF363C46),
    textPrimary: Color(0xFFF5F6F8),
    textSecondary: Color(0xFFA7B0BF),
    textMuted: Color(0xFF6B7480),
    brandPrimary: Color(0xFF4C82FF),
    brandOnPrimary: Color(0xFFFFFFFF),
    brandPrimarySoft: Color(0xFF1B2740),
    statusSuccess: Color(0xFF2ECC87),
    statusDanger: Color(0xFFFF5A6A),
    statusWarning: Color(0xFFFFD84D),
    accentEnergy: Color(0xFFFF7E47),
    segTrack: Color(0xFF0F1217),
    segThumb: Color(0xFF2B303A),
    brightness: Brightness.dark,
  );
}

/// WCA cube-face colors — constant across both themes.
class CubeColors {
  const CubeColors._();

  static const Color white = Color(0xFFFFFFFF);
  static const Color yellow = Color(0xFFFFD500);
  static const Color green = Color(0xFF009E60);
  static const Color blue = Color(0xFF0051BA);
  static const Color red = Color(0xFFC41E3A);
  static const Color orange = Color(0xFFFF5800);
}

/// Sugar: `context.colors.brandPrimary`.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
}
