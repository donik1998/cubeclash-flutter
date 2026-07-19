import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/user_profile.dart';
import '../cubit/profile_cubit.dart';

/// Profile — `/you`.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>(
      create: (_) => sl<ProfileCubit>()..load(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgCanvas,
      appBar: AppBar(
        title: const Text('You'),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/you/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (BuildContext context, ProfileState state) {
          if (state.isLoading) return const LoadingState();

          final UserProfile? profile = state.profile;
          if (profile == null) {
            return ErrorState(
              message: state.failure?.message,
              onRetry: context.read<ProfileCubit>().load,
            );
          }

          return _Body(profile: profile);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final String? flag = countryCodeToFlag(profile.countryCode);

    String? fmt(int? ms) => ms == null ? null : TimeText.format(ms);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Center(
          child: Column(
            children: <Widget>[
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.brandPrimarySoft,
                ),
                alignment: Alignment.center,
                child: Text(
                  profile.displayName.isEmpty
                      ? '?'
                      : profile.displayName.characters.first.toUpperCase(),
                  style: AppTypography.h1.copyWith(color: colors.brandPrimary),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                profile.displayName,
                style: AppTypography.h2.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (flag != null) ...<Widget>[
                    Text(flag, style: AppTypography.body),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    '${profile.solveCount} solves',
                    style: AppTypography.small
                        .copyWith(color: colors.textSecondary),
                  ),
                  if (profile.elo != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '· ${profile.elo} Elo',
                      style: AppTypography.small
                          .copyWith(color: colors.textSecondary),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        Text(
          'PERSONAL BESTS',
          style: AppTypography.overline.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child:
                  StatCard(label: 'Single', value: fmt(profile.bestSingleMs)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(label: 'Ao5', value: fmt(profile.bestAo5Ms)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(label: 'Ao12', value: fmt(profile.bestAo12Ms)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        Text(
          'BADGES',
          style: AppTypography.overline.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        const _BadgesPlaceholder(),
        const SizedBox(height: AppSpacing.x3),
        AppButton.secondary(
          label: 'Friends',
          icon: Icons.people_outline,
          onPressed: () => context.push('/you/friends'),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton.secondary(
          label: 'Settings',
          icon: Icons.settings_outlined,
          onPressed: () => context.push('/you/settings'),
        ),
      ],
    );
  }
}

/// Badges are gamification, which is roadmap. The slot is designed so the
/// profile doesn't look unfinished, and says plainly that it's coming.
class _BadgesPlaceholder extends StatelessWidget {
  const _BadgesPlaceholder();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return AppCard(
      child: Row(
        children: <Widget>[
          for (int i = 0; i < 3; i++) ...<Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.bgSurfaceAlt,
              ),
              child: Icon(
                Icons.workspace_premium_outlined,
                size: 20,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              'Badges arrive with streaks and daily challenges.',
              style: AppTypography.caption.copyWith(color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
