import 'package:flutter/material.dart';

import '../../../../core/widgets/feature_placeholder.dart';

/// Stats: My Stats (PBs, ao5/ao12/ao100, graphs) + Leaderboards
/// (Global / Friends / Country).
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Stats',
      icon: Icons.bar_chart,
      message: 'My Stats · Leaderboards.\n'
          'Averages computed with the WCA rules in ComputeAverages.',
    );
  }
}
