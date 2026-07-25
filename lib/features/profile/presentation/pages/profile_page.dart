import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/badge.dart';
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

          return _Body(profile: profile, badges: state.badges);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.profile, required this.badges});

  final UserProfile profile;
  final List<Badge> badges;

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
                  image: profile.avatarUrl == null
                      ? null
                      : DecorationImage(
                          image: NetworkImage(profile.avatarUrl!),
                          fit: BoxFit.cover,
                        ),
                ),
                alignment: Alignment.center,
                // The initial stands in until (and if) a photo loads.
                child: profile.avatarUrl != null
                    ? null
                    : Text(
                        profile.displayName.isEmpty
                            ? '?'
                            : profile.displayName.characters.first
                                .toUpperCase(),
                        style: AppTypography.h1
                            .copyWith(color: colors.brandPrimary),
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
        _Badges(badges: badges),
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

/// The earned/locked achievement grid. Earned badges read in the brand colour;
/// locked ones are dimmed and, where it counts, show how close you are.
class _Badges extends StatelessWidget {
  const _Badges({required this.badges});

  final List<Badge> badges;

  static IconData _iconFor(BadgeIcon icon) => switch (icon) {
        BadgeIcon.firstSolve => Icons.timer_outlined,
        BadgeIcon.speed => Icons.bolt_outlined,
        BadgeIcon.milestone => Icons.flag_outlined,
        BadgeIcon.streak => Icons.local_fire_department_outlined,
        BadgeIcon.race => Icons.sports_score_outlined,
        BadgeIcon.podium => Icons.emoji_events_outlined,
        BadgeIcon.allEvents => Icons.grid_view_outlined,
        BadgeIcon.comeback => Icons.trending_up_outlined,
      };

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const AppCard(
        child: EmptyState(
          title: 'No badges yet',
          message: 'Solve, race and keep a streak to start earning them.',
          icon: Icons.workspace_premium_outlined,
        ),
      );
    }

    final int earned = badges.where((Badge b) => b.earned).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$earned of ${badges.length} earned',
            style: AppTypography.caption
                .copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              for (final Badge badge in badges)
                _BadgeTile(badge: badge, icon: _iconFor(badge.icon)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.icon});

  final Badge badge;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Color tint = badge.earned ? colors.brandPrimary : colors.textMuted;

    return Tooltip(
      message: badge.earned
          ? badge.description
          : '${badge.description}${badge.progressLabel == null ? '' : '\n${badge.progressLabel}'}',
      child: SizedBox(
        width: 72,
        child: Column(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badge.earned
                    ? colors.brandPrimarySoft
                    : colors.bgSurfaceAlt,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 24, color: tint),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.small.copyWith(
                color: badge.earned ? colors.textPrimary : colors.textMuted,
              ),
            ),
            if (!badge.earned && badge.progressLabel != null)
              Text(
                badge.progressLabel!,
                textAlign: TextAlign.center,
                style: AppTypography.overline.copyWith(color: colors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}
