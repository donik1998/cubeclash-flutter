import 'package:flutter/material.dart';

/// The CubeClash type scale — Noto Serif throughout.
///
/// Source: docs → `05 Design/Design System` § Typography. Sizes are given there
/// as `size/line-height`; here that becomes `fontSize` plus a unitless `height`
/// multiplier (`lineHeight / fontSize`).
///
/// The face is **bundled** as a variable font (`assets/fonts`) and declared in
/// pubspec under the family below, so `fontWeight` drives its `wght` axis
/// directly. Nothing is fetched at runtime — see the note in pubspec.yaml.
///
/// Noto Serif digits are **proportional**, so any number that updates live —
/// the timer readout, times in a list, countdowns — must opt into tabular
/// figures or its width jitters frame to frame. Use [TabularFiguresX.tabular]
/// for that; [display] bakes it in since it only ever renders a time.
class AppTypography {
  const AppTypography._();

  /// Must match the `family:` declared in pubspec.yaml.
  static const String fontFamily = 'Noto Serif';

  static const List<FontFeature> _tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Hero timer readout. ExtraBold 60/64, tabular by default.
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 60,
    height: 64 / 60,
    fontWeight: FontWeight.w800,
    fontFeatures: _tabularFigures,
  );

  /// Bold 32/40.
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
  );

  /// Bold 24/32.
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
  );

  /// SemiBold 18/24.
  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );

  /// Regular 16/24.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  /// SemiBold 16/24 — emphasised body.
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );

  /// Regular 14/20 — scramble text, secondary copy.
  static const TextStyle small = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// Medium 14/20 — form labels, chips.
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );

  /// Medium 12/16 — captions.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  /// SemiBold 11/16, +8% tracking — section eyebrows (`SCRAMBLE`).
  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 11 * 0.08,
  );

  /// Mapped onto Material's [TextTheme] so stock widgets inherit the scale.
  static const TextTheme textTheme = TextTheme(
    displayLarge: display,
    headlineLarge: h1,
    headlineMedium: h2,
    titleLarge: title,
    titleMedium: bodyStrong,
    bodyLarge: body,
    bodyMedium: small,
    labelLarge: label,
    labelMedium: caption,
    labelSmall: overline,
  );
}

/// Opt a style into fixed-width digits.
///
/// Required for every live-updating number — see [AppTypography].
extension TabularFiguresX on TextStyle {
  TextStyle get tabular => copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );
}
