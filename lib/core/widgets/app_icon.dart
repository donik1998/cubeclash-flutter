import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The icon set exported from Figma.
///
/// These are the designers' actual vectors, downloaded from the file and
/// committed — not Material lookalikes and not hand-drawn paths. The design
/// system specifies stroke 2 with round caps and joins, which no stock icon
/// font matches; substituting Material icons is what made the first pass look
/// subtly wrong everywhere.
///
/// Re-export from Figma with the ids recorded in `tool/figma_icons.md` if the
/// design changes.
enum AppIcons {
  chevronDown('chevron-down'),
  refresh('refresh'),
  navTimer('nav-timer'),
  navRace('nav-race'),
  navStats('nav-stats'),
  navYou('nav-you');

  const AppIcons(this.asset);

  final String asset;

  String get path => 'assets/icons/$asset.svg';
}

/// Renders an exported Figma icon, tinted.
///
/// The SVGs carry the colour they were exported with; [color] overrides it via
/// a `srcIn` filter so one asset serves every state (active brand, inactive
/// muted, on-danger, …) rather than needing an export per colour.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final AppIcons icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      icon.path,
      width: size,
      height: size,
      colorFilter:
          color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
    );
  }
}
