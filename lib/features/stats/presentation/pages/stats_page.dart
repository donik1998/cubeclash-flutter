import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/player_stats.dart';
import '../cubit/stats_cubit.dart';
import '../widgets/distribution_chart.dart';
import '../widgets/leaderboard_view.dart';
import '../widgets/progress_chart.dart';

/// The Stats tab — `/stats`. Segmented into My Stats and Leaderboards.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StatsCubit>(
      create: (_) => sl<StatsCubit>()..start(),
      child: const _StatsView(),
    );
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgCanvas,
      appBar: AppBar(title: const Text('Stats')),
      body: BlocBuilder<StatsCubit, StatsState>(
        builder: (BuildContext context, StatsState state) {
          final StatsCubit cubit = context.read<StatsCubit>();

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: AppSegmentedControl(
                  segments: const <String>['My Stats', 'Leaderboards'],
                  selectedIndex: state.segment.index,
                  onChanged: (int i) =>
                      cubit.selectSegment(StatsSegment.values[i]),
                ),
              ),
              Expanded(
                child: switch (state.segment) {
                  StatsSegment.myStats => _MyStats(state: state),
                  StatsSegment.leaderboards =>
                    _LeaderboardsSegment(state: state),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- Segment 1: My Stats -----------------------------------------------------

class _MyStats extends StatelessWidget {
  const _MyStats({required this.state});

  final StatsState state;

  @override
  Widget build(BuildContext context) {
    final StatsCubit cubit = context.read<StatsCubit>();

    if (state.isLoadingStats) return const LoadingState();

    if (state.statsFailure != null) {
      return ErrorState(
        message: state.statsFailure!.message,
        onRetry: cubit.loadStats,
      );
    }

    if (state.statsEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'No stats yet',
        message: 'Record a few solves and your progress will show up here.',
      );
    }

    final PlayerStats stats = state.stats!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.x3,
      ),
      children: <Widget>[
        _PersonalBests(stats: stats),
        const SizedBox(height: AppSpacing.lg),
        if (state.statsTooThin)
          _NeedMoreSolves(stats: stats)
        else ...<Widget>[
          ProgressChart(points: stats.progress),
          const SizedBox(height: AppSpacing.lg),
          DistributionChart(buckets: stats.distribution),
        ],
      ],
    );
  }
}

class _PersonalBests extends StatelessWidget {
  const _PersonalBests({required this.stats});

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    String? fmt(int? ms) => ms == null ? null : TimeText.format(ms);

    // Two rows of two rather than a four-wide row: at 390pt a four-up grid
    // squeezes "1:23.45" past the point of legibility.
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: StatCard(
                label: 'Best single',
                value: fmt(stats.bestSingleMs),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(label: 'Best Ao5', value: fmt(stats.bestAo5Ms)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: StatCard(label: 'Best Ao12', value: fmt(stats.bestAo12Ms)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child:
                  StatCard(label: 'Best Ao100', value: fmt(stats.bestAo100Ms)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shown when there are solves but not enough for a chart to be meaningful.
class _NeedMoreSolves extends StatelessWidget {
  const _NeedMoreSolves({required this.stats});

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final int remaining = PlayerStats.minimumSolvesForCharts - stats.solveCount;

    return AppCard(
      child: Column(
        children: <Widget>[
          Icon(Icons.show_chart, size: 32, color: colors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Charts unlock at ${PlayerStats.minimumSolvesForCharts} solves',
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$remaining more to go — a trend needs a few points before it '
            'means anything.',
            textAlign: TextAlign.center,
            style: AppTypography.small.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// --- Segment 2: Leaderboards -------------------------------------------------

/// Layer A for the Leaderboards segment: reads the cubit and hands plain values
/// and callbacks to the pure [LeaderboardView]. No layout or styling here.
class _LeaderboardsSegment extends StatelessWidget {
  const _LeaderboardsSegment({required this.state});

  final StatsState state;

  @override
  Widget build(BuildContext context) {
    final StatsCubit cubit = context.read<StatsCubit>();

    // Surface the error only when there is nothing usable to show; a failure
    // on top of an already-loaded page keeps the page.
    final bool hasNothing = state.leaderboard?.entries.isEmpty ?? true;
    final String? failureMessage =
        (state.leaderboardFailure != null && hasNothing)
            ? state.leaderboardFailure!.message
            : null;

    return LeaderboardView(
      scope: state.scope,
      metric: state.metric,
      isLoading: state.isLoadingLeaderboard,
      isLoadingMore: state.isLoadingMore,
      isEmpty: state.leaderboardEmpty,
      failureMessage: failureMessage,
      leaderboard: state.leaderboard,
      pinnedViewer: state.pinnedViewer,
      onScopeChanged: cubit.changeScope,
      onMetricChanged: cubit.changeMetric,
      onRetry: cubit.loadLeaderboard,
      onLoadMore: cubit.loadMoreLeaderboard,
      onTapEntry: (String userId) => context.push('/stats/player/$userId'),
      formatTime: TimeText.format,
    );
  }
}
