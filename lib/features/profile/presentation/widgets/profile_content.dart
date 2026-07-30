import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/country_names.dart';
import '../../../../core/util/number_format.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/profile_summary.dart';
import 'profile_menu_row.dart';
import 'profile_subtitle.dart';
import 'stat_row.dart';

/// The pure body of the You · Profile screen (Figma `47:164`).
///
/// **Layer B: it never reaches for state.** No bloc, no get_it, no cubit — it
/// takes a resolved [summary] plus loading/error flags and three callbacks, so
/// every state (including the awkward ones) is reachable in a golden without
/// booting a container.
///
/// All human formatting lives here (spec §9): the country code → name, ms →
/// `8.42`, the ratio → `68%`, thousands separators, the `#` and `Elo` prefixes.
class ProfileContent extends StatelessWidget {
  const ProfileContent({
    super.key,
    required this.summary,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    required this.onFriends,
    required this.onShare,
    required this.onSettings,
    this.errorMessage,
  });

  final ProfileSummary? summary;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onFriends;
  final VoidCallback onShare;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        children: <Widget>[
          Text(
            'Profile',
            style: AppTypography.h1.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          _body(context),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (isLoading) return const _ProfileSkeleton();

    final ProfileSummary? data = summary;
    if (hasError || data == null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x5),
        child: ErrorState(message: errorMessage, onRetry: onRetry),
      );
    }

    return _Loaded(
      summary: data,
      onFriends: onFriends,
      onShare: onShare,
      onSettings: onSettings,
    );
  }
}

/// The populated hero + stat row + menu, given a resolved [summary].
class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.summary,
    required this.onFriends,
    required this.onShare,
    required this.onSettings,
  });

  final ProfileSummary summary;
  final VoidCallback onFriends;
  final VoidCallback onShare;
  final VoidCallback onSettings;

  String? _bestValue() {
    final int? ms = summary.bestSingleMs;
    return ms == null ? null : TimeText.format(ms);
  }

  String? _winRateValue() {
    final double? r = summary.winRate;
    return r == null ? null : '${(r * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Column(
      children: <Widget>[
        _Hero(summary: summary),
        const SizedBox(height: AppSpacing.md),
        StatRow(
          tiles: <StatTileData>[
            StatTileData(value: _bestValue(), label: 'best'),
            StatTileData(
              value: groupThousands(summary.totalSolves),
              label: 'solves',
            ),
            StatTileData(value: _winRateValue(), label: 'win rate'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              ProfileMenuRow(
                icon: Icons.people_outline,
                iconTileColor: colors.brandPrimary,
                label: 'Friends',
                trailingValue: groupThousands(summary.friendCount),
                onTap: onFriends,
              ),
              const Divider(height: 1, thickness: 1, indent: 56),
              ProfileMenuRow(
                icon: Icons.ios_share,
                iconTileColor: colors.statusSuccess,
                label: 'Share profile',
                onTap: onShare,
              ),
              const Divider(height: 1, thickness: 1, indent: 56),
              ProfileMenuRow(
                icon: Icons.settings_outlined,
                iconTileColor: colors.bgSurfaceAlt,
                iconColor: colors.textMuted,
                label: 'Settings',
                onTap: onSettings,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The hero card (Figma `47:165`): avatar, username, subtitle, centered.
class _Hero extends StatelessWidget {
  const _Hero({required this.summary});

  final ProfileSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: <Widget>[
          ProfileAvatar(displayName: summary.displayName),
          const SizedBox(height: AppSpacing.sm - 2), // 6
          Text(
            summary.displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.miniStat.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm - 2), // 6
          ProfileSubtitle(
            countryName: countryCodeToName(summary.countryCode),
            elo: summary.elo,
            rankPosition: summary.rank == null
                ? null
                : groupThousands(summary.rank!.position),
          ),
        ],
      ),
    );
  }
}

/// The loading placeholder: a hero block, three tiles and three menu rows in
/// muted surfaces, so the screen keeps its shape while the fetch is in flight
/// (spec §8 Loading).
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    Widget block(double height,
            {double? width, double radius = AppRadius.md}) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colors.bgSurfaceAlt,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        block(150, radius: AppRadius.card),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            for (int i = 0; i < 3; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              Expanded(child: block(66, radius: AppRadius.statTile)),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        block(174, radius: AppRadius.card),
      ],
    );
  }
}
