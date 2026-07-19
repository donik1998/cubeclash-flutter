import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

/// Welcome / onboarding — `/auth`.
///
/// Not in the Figma 14; designed from the design system to match. One screen
/// rather than a carousel: the app is a timer and a race, and three swipes of
/// marketing before someone can time a solve is three swipes too many.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(),
              Center(
                child: CubeFaceIcon(
                  size: 88,
                  active: true,
                  color: colors.brandPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              Text(
                'CubeClash',
                textAlign: TextAlign.center,
                style: AppTypography.h1.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'A WCA timer that races.\nSame scramble, same moment, '
                'someone else on the other end.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.x4),
              const _Highlights(),
              const Spacer(),
              AppButton(
                label: 'Create an account',
                onPressed: () => context.push('/auth/register'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.secondary(
                label: 'I already have one',
                onPressed: () => context.push('/auth/login'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights();

  static const List<(IconData, String)> _items = <(IconData, String)>[
    (Icons.timer_outlined, 'WCA inspection, +2 and DNF, done properly'),
    (Icons.bolt_outlined, 'Live 1v1 races on a shared scramble'),
    (Icons.bar_chart_outlined, 'Ao5, Ao12 and where you rank'),
  ];

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Column(
      children: <Widget>[
        for (final (IconData icon, String label) in _items) ...<Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.brandPrimarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 18, color: colors.brandPrimary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style:
                      AppTypography.small.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
