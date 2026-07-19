import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Builds the light / dark [ThemeData] from design-system tokens.
///
/// Typeface is Noto Serif throughout (via google_fonts). Widgets read semantic
/// tokens through `context.colors`; this maps the essentials onto Material so
/// stock widgets look right too.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(AppColors.light);
  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppColors c) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: c.brandPrimary,
      brightness: c.brightness,
    ).copyWith(
      primary: c.brandPrimary,
      onPrimary: c.brandOnPrimary,
      surface: c.bgSurface,
      error: c.statusDanger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bgCanvas,
      dividerColor: c.borderSubtle,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.textTheme.apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgCanvas,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
