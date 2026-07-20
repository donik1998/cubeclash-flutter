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

  /// ExtraBold 78 — the timer hero (Figma `21:72`).
  ///
  /// Larger than [display]'s 60: the frame sizes the readout to be legible
  /// from across a table, which is where a phone sits during a solve. Tabular
  /// by default, since it only ever renders a time.
  static const TextStyle timerHero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 78,
    fontWeight: FontWeight.w800,
    fontFeatures: _tabularFigures,
  );

  /// Bold 22 — the value on a session stat card (Figma `21:78`).
  static const TextStyle miniStat = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  /// Medium 15 — the timer's state label (Figma `21:75`).
  static const TextStyle stateLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  /// Medium 19/28 — the scramble itself.
  ///
  /// Off the standard scale, from the Figma frame (`Timer Home → scramble`).
  /// It earns the exception: this is the one string a cuber reads mid-turn,
  /// with the phone on a table at arm's length, so it is sized for that rather
  /// than for the body role it would otherwise take.
  static const TextStyle scramble = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    height: 28 / 19,
    fontWeight: FontWeight.w500,
  );

  /// Medium 16/24 — the scramble at 4×4/5×5 length.
  ///
  /// Not in the Figma frame, which only ever showed a 3×3. Added here rather
  /// than inline because the ramp is a rule, not a one-off: a 5×5 scramble is
  /// three times a 3×3's length and at 19/28 it pushes the timer off screen.
  /// Derived from [scramble] on the same 1.47 line-height ratio so the two
  /// read as one style at two sizes.
  static const TextStyle scrambleCompact = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
  );

  /// Medium 13/19 — the scramble at 6×6/7×7/Megaminx length.
  ///
  /// The floor of the ramp. Below this a scramble stops being readable at
  /// arm's length, which is the only reason the card exists — so the card
  /// collapses and offers an expander instead of shrinking further.
  static const TextStyle scrambleDense = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 19 / 13,
    fontWeight: FontWeight.w500,
  );

  // --- Race ------------------------------------------------------------------
  // Off the standard scale, taken from the Race frames. The versus screens are
  // the one place two numbers are read side by side and compared at a glance,
  // so they get their own sizes rather than borrowing the solo timer's.

  /// ExtraBold 30 — a lobby screen title (Figma `33:111`).
  ///
  /// The tab screens title themselves in the body rather than in an app bar,
  /// which is why this sits between [h1] and [h2] instead of reusing either.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    fontWeight: FontWeight.w800,
  );

  /// Bold 20 — a lobby hero card's title (Figma `33:123`).
  static const TextStyle heroTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  /// SemiBold 13 — pill labels: the Elo chip, a rival's Race button
  /// (Figma `33:113`).
  static const TextStyle pillLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Bold 12, +12% tracking — the `LIVE RACE` overline (Figma `34:147`).
  ///
  /// Heavier and wider-tracked than [overline]: it is a status, not a section
  /// heading, and it is the only thing on the screen rendered in `status/danger`.
  static const TextStyle liveOverline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.44,
  );

  /// SemiBold 15 — a player's name on a versus card (Figma `34:152`).
  static const TextStyle versusName = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  /// Bold 30 — a player's clock on a versus card (Figma `34:154`).
  ///
  /// Both players' clocks render at this size. That equality is the whole
  /// point of the screen: neither time is the hero, which is what makes it
  /// read as a race rather than as your timer with a footnote.
  static const TextStyle versusTime = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabularFigures,
  );

  /// Bold 18 — the `VS` between the two cards (Figma `34:156`).
  static const TextStyle versusJoin = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  /// Medium 16 — the prompt filling the lower half of a race screen, e.g.
  /// `Tap anywhere to stop` (Figma `34:166`).
  static const TextStyle stagePrompt = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  /// ExtraBold 46 — `YOU WIN` / `YOU LOSE` (Figma `34:193`).
  static const TextStyle resultHeadline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 46,
    fontWeight: FontWeight.w800,
  );

  /// ExtraBold 26 — a private room's shareable code (Figma `33:207`).
  ///
  /// Tabular: the code is read aloud and typed in character by character, so
  /// even letter-spacing matters more than tight fitting.
  static const TextStyle roomCode = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    fontFeatures: _tabularFigures,
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
