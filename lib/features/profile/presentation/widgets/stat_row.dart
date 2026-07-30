import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// The three summary tiles under the hero (Figma `47:169`): best · solves ·
/// win rate, laid out in an equal-width row with a 12 gap.
///
/// Layout only — it takes three pre-formatted (value, label) pairs and renders
/// a [StatCard] in value-first mode for each. Values are formatted upstream
/// (`—` for a missing best or win rate).
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.tiles});

  /// Exactly three (value, label) pairs, in order.
  final List<StatTileData> tiles;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight so the three tiles share the tallest one's height
    // (they're symmetric, so this is just insurance) without needing a bounded
    // parent — a plain `stretch` would demand infinite height inside a
    // ListView.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < tiles.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                value: tiles[i].value,
                label: tiles[i].label,
                valueFirst: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single tile's pre-formatted content.
class StatTileData {
  const StatTileData({required this.value, required this.label});

  /// Pre-formatted display value; null renders `—`.
  final String? value;
  final String label;
}
