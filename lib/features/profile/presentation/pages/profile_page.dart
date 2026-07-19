import 'package:flutter/material.dart';

import '../../../../core/widgets/feature_placeholder.dart';

/// You: profile (display name, country, PBs), friends, and settings
/// (theme · timer style · haptics · inspection).
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'You',
      icon: Icons.person,
      message: 'Profile · Friends · Settings.',
    );
  }
}
