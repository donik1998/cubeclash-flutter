import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// The muted line under the username on the hero (Figma `47:168`):
/// `Uzbekistan · Elo 1180 · #1,204` — country name · Elo rating · global rank.
///
/// Joins **only the present segments** with " · " (spec §6 drop rules):
///   * null [countryName] → the country segment is dropped.
///   * null [rankPosition] → the "#…" segment is dropped.
///   * Elo is always shown as `Elo {elo}`.
///
/// Everything here is already formatted by the caller — the country code is
/// resolved to a name upstream, and [rankPosition] is the grouped string
/// ("1,204"), not the raw number.
class ProfileSubtitle extends StatelessWidget {
  const ProfileSubtitle({
    super.key,
    required this.countryName,
    required this.elo,
    required this.rankPosition,
  });

  final String? countryName;
  final int elo;

  /// The thousands-grouped rank string (e.g. "1,204") or null. The "#" prefix
  /// is added here; the caller passes just the grouped number.
  final String? rankPosition;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    final List<String> segments = <String>[
      if (countryName != null) countryName!,
      'Elo $elo',
      if (rankPosition != null) '#$rankPosition',
    ];

    return Text(
      segments.join(' · '),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.caption.copyWith(color: colors.textMuted).tabular,
    );
  }
}
