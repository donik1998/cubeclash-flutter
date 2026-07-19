import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/player_stats.dart';
import '../cubit/stats_cubit.dart';
import '../widgets/distribution_chart.dart';
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
                  StatsSegment.leaderboards => _Leaderboards(state: state),
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

class _Leaderboards extends StatefulWidget {
  const _Leaderboards({required this.state});

  final StatsState state;

  @override
  State<_Leaderboards> createState() => _LeaderboardsState();
}

class _LeaderboardsState extends State<_Leaderboards> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final double remaining =
        _controller.position.maxScrollExtent - _controller.position.pixels;
    if (remaining < 400) context.read<StatsCubit>().loadMoreLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    final StatsState state = widget.state;
    final StatsCubit cubit = context.read<StatsCubit>();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: <Widget>[
              AppSegmentedControl(
                segments: LeaderboardScope.values
                    .map((LeaderboardScope s) => s.label)
                    .toList(),
                selectedIndex: state.scope.index,
                onChanged: (int i) =>
                    cubit.changeScope(LeaderboardScope.values[i]),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  for (final LeaderboardMetric metric
                      in LeaderboardMetric.values) ...<Widget>[
                    AppChip(
                      label: metric.label,
                      selected: state.metric == metric,
                      onTap: () => cubit.changeMetric(metric),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
            child: _LeaderboardBody(state: state, controller: _controller)),
        // The user's own row, pinned, when it isn't already on screen — the
        // most useful thing a leaderboard can tell you is where you are.
        if (state.pinnedCurrentUser case final LeaderboardEntry me)
          _PinnedRow(entry: me),
      ],
    );
  }
}

class _LeaderboardBody extends StatelessWidget {
  const _LeaderboardBody({required this.state, required this.controller});

  final StatsState state;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final StatsCubit cubit = context.read<StatsCubit>();

    if (state.isLoadingLeaderboard) return const LoadingState();

    if (state.leaderboardFailure != null &&
        (state.leaderboard?.entries.isEmpty ?? true)) {
      return ErrorState(
        message: state.leaderboardFailure!.message,
        onRetry: cubit.loadLeaderboard,
      );
    }

    if (state.leaderboardEmpty) {
      return EmptyState(
        icon: Icons.leaderboard_outlined,
        title: switch (state.scope) {
          LeaderboardScope.friends => 'No friends ranked yet',
          LeaderboardScope.country => 'Nobody from your country yet',
          LeaderboardScope.global => 'No rankings yet',
        },
        message: state.scope == LeaderboardScope.friends
            ? 'Add friends and their times will show up here.'
            : 'Check back once more people have competed.',
      );
    }

    final List<LeaderboardEntry> entries = state.leaderboard!.entries;

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      itemCount: entries.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index >= entries.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final LeaderboardEntry entry = entries[index];
        return LeaderboardRow(
          rank: entry.rank,
          displayName: entry.displayName,
          time: TimeText.format(entry.timeMs),
          countryCode: entry.countryCode,
          avatarUrl: entry.avatarUrl,
          isCurrentUser: entry.isCurrentUser,
          onTap: () => context.push('/stats/player/${entry.userId}'),
        );
      },
    );
  }
}

class _PinnedRow extends StatelessWidget {
  const _PinnedRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: SafeArea(
        top: false,
        child: LeaderboardRow(
          rank: entry.rank,
          displayName: entry.displayName,
          time: TimeText.format(entry.timeMs),
          countryCode: entry.countryCode,
          avatarUrl: entry.avatarUrl,
          isCurrentUser: true,
        ),
      ),
    );
  }
}
