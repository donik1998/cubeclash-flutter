/// Spacing scale from the design system: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double x3 = 32;
  static const double x4 = 40;
  static const double x5 = 48;
  static const double x6 = 64;
}

/// Corner radii from the design system.
class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  // --- Component radii -------------------------------------------------------
  // The design system specifies these off the sm/md/lg/xl scale. They are
  // tokens rather than inline literals so the exception stays in one place.
  //   docs → 05 Design/Design System § Components

  /// Buttons — 14 (design system, deliberately between [md] and [lg]).
  static const double button = 14;

  /// Inputs — 12 (aliases [md]).
  static const double input = md;

  /// Cards — 16 (aliases [lg]).
  static const double card = lg;
}
