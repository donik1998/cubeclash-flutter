import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../cubit/player_profile_cubit.dart';

/// Player Profile — `/stats/player/:id`, pushed full-screen.
///
/// Their PBs and country, plus the head-to-head record against you, which is
/// the reason you tapped a name on a leaderboard in the first place.
class PlayerProfilePage extends StatelessWidget {
  const PlayerProfilePage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PlayerProfileCubit>(
      create: (_) => sl<PlayerProfileCubit>()..load(userId),
      child: const _PlayerProfileView(),
    );
  }
}

class _PlayerProfileView extends StatelessWidget {
  const _PlayerProfileView();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgCanvas,
      appBar: AppBar(title: const Text('Player')),
      body: BlocBuilder<PlayerProfileCubit, PlayerProfileState>(
        builder: (BuildContext context, PlayerProfileState state) {
          if (state.isLoading) return const LoadingState();

          final PlayerProfile? profile = state.profile;
          if (profile == null) {
            return ErrorState(
              title: 'Player not found',
              message: state.failure?.message,
              onRetry: () =>
                  context.read<PlayerProfileCubit>().load(state.userId),
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

  final PlayerProfile profile;

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
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.bgSurfaceAlt,
                  image: profile.avatarUrl == null
                      ? null
                      : DecorationImage(
                          image: NetworkImage(profile.avatarUrl!),
                          fit: BoxFit.cover,
                        ),
                ),
                alignment: Alignment.center,
                child: profile.avatarUrl != null
                    ? null
                    : Text(
                        profile.displayName.isEmpty
                            ? '?'
                            : profile.displayName.characters.first
                                .toUpperCase(),
                        style: AppTypography.h2
                            .copyWith(color: colors.textSecondary),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                profile.displayName,
                style: AppTypography.h2.copyWith(color: colors.textPrimary),
              ),
              if (flag != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(flag, style: AppTypography.title),
              ],
              if (profile.elo != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                // Server-owned rating. Displayed, never derived.
                AppChip(
                  label: '${profile.elo} Elo',
                  variant: AppChipVariant.event,
                ),
              ],
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
              child: StatCard(
                label: 'Single',
                value: fmt(profile.bestSingleMs),
              ),
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
          'HEAD TO HEAD',
          style: AppTypography.overline.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        _HeadToHeadCard(
          record: profile.headToHead,
          opponentName: profile.displayName,
        ),
      ],
    );
  }
}

class _HeadToHeadCard extends StatelessWidget {
  const _HeadToHeadCard({required this.record, required this.opponentName});

  final HeadToHead? record;
  final String opponentName;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    if (record == null || record!.total == 0) {
      return AppCard(
        child: Column(
          children: <Widget>[
            Text(
              "You haven't raced $opponentName yet",
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    final HeadToHead h2h = record!;

    return AppCard(
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _Tally(
                value: h2h.wins,
                label: 'You',
                color: colors.statusSuccess,
              ),
              Text(
                '–',
                style: AppTypography.h2.copyWith(color: colors.textMuted),
              ),
              _Tally(
                value: h2h.losses,
                label: opponentName,
                color: colors.statusDanger,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${h2h.total} race${h2h.total == 1 ? '' : 's'}',
            style: AppTypography.caption.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          '$value',
          style: AppTypography.h1.copyWith(color: color).tabular,
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: 100,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style:
                AppTypography.caption.copyWith(color: context.colors.textMuted),
          ),
        ),
      ],
    );
  }
}
