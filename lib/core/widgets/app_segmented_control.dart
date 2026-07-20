import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// iOS-style segmented control: a recessed `seg/track` with an elevated
/// `seg/thumb` that animates between segments.
///
/// Used for Race lobby (Quick / Private / Tournaments), Stats (My Stats /
/// Leaderboards) and leaderboard scope (Global / Friends / Country).
///
/// The thumb is laid out with a [Stack] + [AnimatedAlign] rather than an
/// animated `left` offset so it stays correct at any width without a
/// LayoutBuilder measure pass.
class AppSegmentedControl extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // Checked here rather than in the constructor: `segments.length` is not
    // const-evaluable, so a constructor assert would forbid `const` call sites.
    assert(segments.length > 1, 'A segmented control needs 2+ segments');

    final AppColors colors = context.colors;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    // -1 → +1 across the track, so AnimatedAlign lands the thumb on segment i.
    final double alignX = segments.length == 1
        ? 0
        : (selectedIndex / (segments.length - 1)) * 2 - 1;

    return Container(
      // Pill, not a rounded rectangle, and a tighter 3pt inset than the
      // spacing scale's 4 — Figma `33:115`. Both the track and the thumb are
      // fully rounded there.
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.segTrack,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AnimatedAlign(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment(alignX, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / segments.length,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.segThumb,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              for (int i = 0; i < segments.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selectedIndex,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Container(
                        // 40 + 4pt track padding either side clears 48dp.
                        constraints: const BoxConstraints(minHeight: 40),
                        alignment: Alignment.center,
                        child: Text(
                          segments[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          // 12, not the label scale's 14 — three segments have
                          // to fit `Quick Match` / `Private` / `Tournaments`
                          // across a phone without ellipsing (Figma `33:117`).
                          style: AppTypography.caption.copyWith(
                            color: i == selectedIndex
                                ? colors.textPrimary
                                : colors.textSecondary,
                            fontWeight: i == selectedIndex
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
