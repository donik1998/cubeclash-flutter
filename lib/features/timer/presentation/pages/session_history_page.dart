import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/penalty.dart';
import '../../domain/entities/solve.dart';
import '../cubit/history_cubit.dart';

/// Session & History — `/timer/history`.
///
/// Session summary at the top, then every solve grouped by day, paged in as
/// the user scrolls.
class SessionHistoryPage extends StatelessWidget {
  const SessionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HistoryCubit>(
      create: (_) => sl<HistoryCubit>()..load(),
      child: const _HistoryView(),
    );
  }
}

class _HistoryView extends StatefulWidget {
  const _HistoryView();

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
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

  /// Fetch a screen early so the next page is usually there before the user
  /// reaches the bottom.
  void _onScroll() {
    if (!_controller.hasClients) return;
    final double remaining =
        _controller.position.maxScrollExtent - _controller.position.pixels;
    if (remaining < 600) context.read<HistoryCubit>().loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgCanvas,
      appBar: AppBar(
        title: const Text('History'),
        actions: <Widget>[
          BlocBuilder<HistoryCubit, HistoryState>(
            builder: (BuildContext context, HistoryState state) => TextButton(
              onPressed:
                  state.solves.isEmpty ? null : () => _confirmClear(context),
              child: const Text('Clear session'),
            ),
          ),
        ],
      ),
      body: BlocBuilder<HistoryCubit, HistoryState>(
        builder: (BuildContext context, HistoryState state) {
          if (state.isLoading) return const LoadingState();

          // A failure with nothing loaded is a dead end; a failure *while*
          // paging is not — keep the rows and report the append failure below.
          if (state.failure != null && state.solves.isEmpty) {
            return ErrorState(
              message: state.failure!.message,
              onRetry: () => context.read<HistoryCubit>().load(),
            );
          }

          if (state.isEmpty) {
            return EmptyState(
              icon: Icons.timer_outlined,
              title: 'No solves yet',
              message: 'Every solve you time will show up here.',
              actionLabel: 'Start solving',
              onAction: () => context.pop(),
            );
          }

          return _Body(state: state, controller: _controller);
        },
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final HistoryCubit cubit = context.read<HistoryCubit>();

    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            backgroundColor: dialogContext.colors.bgSurface,
            title: const Text('Clear this session?'),
            content: const Text(
              'Your solves are kept in history — only the current session '
              'grouping resets.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Clear'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) await cubit.clearSession();
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.controller});

  final HistoryState state;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final HistoryCubit cubit = context.read<HistoryCubit>();
    final List<({DateTime day, List<Solve> solves})> groups = state.byDay;

    return CustomScrollView(
      controller: controller,
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: _SummaryRow(stats: cubit.statsFor(state.solves)),
          ),
        ),
        for (final ({DateTime day, List<Solve> solves}) group in groups) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(
              child: _DayHeader(day: group.day, count: group.solves.length),
            ),
          ),
          SliverList.builder(
            itemCount: group.solves.length,
            itemBuilder: (BuildContext context, int index) =>
                _SolveRow(solve: group.solves[index]),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: state.isLoadingMore
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : state.hasMore
                      ? const SizedBox.shrink()
                      : Text(
                          'That\'s everything.',
                          style: AppTypography.caption
                              .copyWith(color: context.colors.textMuted),
                        ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.stats});

  final ({int? best, int? ao5, int? ao12}) stats;

  @override
  Widget build(BuildContext context) {
    String? fmt(int? ms) => ms == null ? null : TimeText.format(ms);

    return Row(
      children: <Widget>[
        Expanded(child: StatCard(label: 'Best', value: fmt(stats.best))),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: StatCard(label: 'Ao5', value: fmt(stats.ao5))),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: StatCard(label: 'Ao12', value: fmt(stats.ao12))),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Row(
      children: <Widget>[
        Text(
          _label(day),
          style: AppTypography.overline.copyWith(color: colors.textMuted),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '· $count solve${count == 1 ? '' : 's'}',
          style: AppTypography.caption.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }

  static String _label(DateTime day) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int daysAgo = today.difference(day).inDays;

    if (daysAgo == 0) return 'TODAY';
    if (daysAgo == 1) return 'YESTERDAY';

    const List<String> months = <String>[
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return '${day.day} ${months[day.month - 1]}';
  }
}

class _SolveRow extends StatelessWidget {
  const _SolveRow({required this.solve});

  final Solve solve;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return InkWell(
      onTap: () => context.push('/timer/solve/${solve.id}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 76,
              child: TimeText(
                timeMs: solve.timeMs,
                isPlus2: solve.penalty == Penalty.plus2,
                isDnf: solve.isDnf,
                style: AppTypography.bodyStrong,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                solve.scramble,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(color: colors.textMuted),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _time(solve.solvedAt),
              style: AppTypography.caption
                  .copyWith(color: colors.textMuted)
                  .tabular,
            ),
          ],
        ),
      ),
    );
  }

  static String _time(DateTime when) =>
      '${when.hour.toString().padLeft(2, '0')}:'
      '${when.minute.toString().padLeft(2, '0')}';
}
