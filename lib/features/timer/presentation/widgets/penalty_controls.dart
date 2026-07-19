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
  });

  final Penalty penalty;
  final bool enabled;
  final ValueChanged<Penalty> onChanged;

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
            AppChip(
              label: '+2',
              variant: AppChipVariant.plus2,
              selected: penalty == Penalty.plus2,
              onTap: () => toggle(Penalty.plus2),
            ),
            const SizedBox(width: AppSpacing.sm),
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
