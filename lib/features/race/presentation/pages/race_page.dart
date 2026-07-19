import 'package:flutter/material.dart';

import '../../../../core/widgets/feature_placeholder.dart';

/// Race lobby: Quick Match · Private (invite code) · Tournaments. The live race
/// runs full-screen over the WebSocket gateway — docs/Real-time Race Protocol.
class RacePage extends StatelessWidget {
  const RacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Race',
      icon: Icons.bolt,
      message: 'Quick Match · Private · Tournaments.\n'
          'Server-authoritative live races over WebSocket — coming next.',
    );
  }
}
