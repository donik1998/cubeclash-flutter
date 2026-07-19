import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Timer home (default tab). Proposes a fresh WCA scramble every solve, then a
/// giant timer with inspection + penalty controls.
///
/// This is the static shell. The idle → ready → running → stopped state machine
/// is implemented as a Timer BLoC next — see docs/Flutter App Architecture.
class TimerPage extends StatelessWidget {
  const TimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timer'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Chip(
              label: const Text('3×3'),
              backgroundColor: colors.brandPrimarySoft,
              labelStyle: TextStyle(color: colors.brandPrimary),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ScrambleCard(colors: colors),
            const Spacer(),
            Center(
              child: Text(
                '0.00',
                style: TextStyle(
                  fontSize: 76,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                'Hold to start',
                style: TextStyle(color: colors.textMuted),
              ),
            ),
            const Spacer(),
            Text(
              'Timer state machine (inspection · +2 / DNF · last-solves) '
              'wires in via the Timer BLoC — TODO.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrambleCard extends StatelessWidget {
  const _ScrambleCard({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'SCRAMBLE',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "R U R' U' F2 L' D2 R2 B",
            style: TextStyle(color: colors.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
