import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/penalty.dart';

/// `+2` · `DNF` · `clear`, acting on the solve just completed.
///
/// Only live immediately after a solve — [enabled] is false at every other
/// point in the state machine, because there is nothing to penalise.
class PenaltyControls extends StatelessWidget {
  const PenaltyControls({
    super.key,
    required this.penalty,
    required this.enabled,
    required this.onChanged,
    this.showPlus2 = true,
  });

  final Penalty penalty;
  final bool enabled;
  final ValueChanged<Penalty> onChanged;

  /// Whether a `+2` is a coherent penalty for this event.
  ///
  /// It is not for Fewest Moves (two seconds added to a move count is
  /// nonsense) or Multi-Blind (no inspection to overrun), so the chip is
  /// removed rather than shown as a button that would lie about the result.
  /// A **DNF stays for every event** — any attempt can fail.
  final bool showPlus2;

  @override
  Widget build(BuildContext context) {
    // Tapping the active penalty again clears it — the obvious gesture, and it
    // saves a trip to the `clear` button for the common mis-tap.
    void toggle(Penalty tapped) =>
        onChanged(penalty == tapped ? Penalty.none : tapped);

    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (showPlus2) ...<Widget>[
              AppChip(
                label: '+2',
                variant: AppChipVariant.plus2,
                selected: penalty == Penalty.plus2,
                onTap: () => toggle(Penalty.plus2),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            AppChip(
              label: 'DNF',
              variant: AppChipVariant.dnf,
              selected: penalty == Penalty.dnf,
              onTap: () => toggle(Penalty.dnf),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppChip(
              label: 'Clear',
              selected: penalty == Penalty.none,
              onTap: () => onChanged(Penalty.none),
            ),
          ],
        ),
      ),
    );
  }
}
