import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/leaderboard_entry.dart';
import 'leaderboard_gap.dart';

/// The Leaderboards segment body — **pure**. It takes resolved values and
/// callbacks and imports no BLoC/Cubit or DI, so every state (loading, empty,
/// error, populated, viewer-pinned) is reachable in a widget test without a
/// container. The [StatsPage] layer owns the cubit and hands data down.
///
/// Layout, top to bottom (Figma `Stats · Leaderboards`, `45:704` / `44:158`):
/// scope tabs → metric chips → the ranked cards → a `· · ·` gap → the pinned
/// viewer row above the nav.
class LeaderboardView extends StatefulWidget {
  const LeaderboardView({
    super.key,
    required this.scope,
    required this.metric,
    required this.isLoading,
    required this.isLoadingMore,
    required this.isEmpty,
    required this.failureMessage,
    required this.leaderboard,
    required this.pinnedViewer,
    required this.onScopeChanged,
    required this.onMetricChanged,
    required this.onRetry,
    required this.onLoadMore,
    required this.onTapEntry,
    required this.formatTime,
  });

  final LeaderboardScope scope;
  final LeaderboardMetric metric;

  final bool isLoading;
  final bool isLoadingMore;
  final bool isEmpty;

  /// Non-null only when the list failed *and* nothing usable is loaded.
  final String? failureMessage;

  final Leaderboard? leaderboard;

  /// The viewer's row to pin at the bottom — non-null only when they are off
  /// the loaded page (`StatsState.pinnedViewer`).
  final LeaderboardEntry? pinnedViewer;

  final ValueChanged<LeaderboardScope> onScopeChanged;
  final ValueChanged<LeaderboardMetric> onMetricChanged;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final ValueChanged<String> onTapEntry;

  /// Milliseconds → a WCA-formatted, tabular string. Injected so this widget
  /// stays free of the time-format util's import graph and is trivially stubbed.
  final String Function(int timeMs) formatTime;

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
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
    if (remaining < 400) widget.onLoadMore();
  }

  @override
  Widget build(BuildContext context) {
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
                selectedIndex: widget.scope.index,
                onChanged: (int i) =>
                    widget.onScopeChanged(LeaderboardScope.values[i]),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  for (final LeaderboardMetric metric
                      in LeaderboardMetric.values) ...<Widget>[
                    AppChip(
                      label: metric.label,
                      selected: widget.metric == metric,
                      onTap: () => widget.onMetricChanged(metric),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(child: _body(context)),
        if (widget.pinnedViewer case final LeaderboardEntry me)
          _PinnedRow(entry: me, formatTime: widget.formatTime),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (widget.isLoading) return const LoadingState();

    if (widget.failureMessage != null) {
      return ErrorState(
          message: widget.failureMessage!, onRetry: widget.onRetry);
    }

    if (widget.isEmpty) {
      return EmptyState(
        icon: Icons.leaderboard_outlined,
        title: switch (widget.scope) {
          LeaderboardScope.friends => 'No friends ranked yet',
          LeaderboardScope.country => 'Nobody from your country yet',
          LeaderboardScope.global => 'No rankings yet',
        },
        message: widget.scope == LeaderboardScope.friends
            ? 'Add friends and their times will show up here.'
            : 'Check back once more people have competed.',
      );
    }

    final List<LeaderboardEntry> entries =
        widget.leaderboard?.entries ?? const <LeaderboardEntry>[];
    final bool showGap = widget.pinnedViewer != null;

    // rows + between-row gaps + optional gap indicator + optional footer spinner
    return ListView.separated(
      controller: _controller,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      itemCount:
          entries.length + (showGap ? 1 : 0) + (widget.isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (BuildContext context, int index) {
        if (index < entries.length) {
          final LeaderboardEntry entry = entries[index];
          return LeaderboardRow(
            rank: entry.rank,
            displayName: entry.displayName,
            time: widget.formatTime(entry.timeMs),
            countryCode: entry.countryCode,
            isCurrentUser: entry.isCurrentUser,
            onTap: () => widget.onTapEntry(entry.userId),
          );
        }
        if (showGap && index == entries.length) {
          return const LeaderboardGap();
        }
        return const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}

/// The viewer's row, pinned above the nav with a top border on `bg/surface`
/// (Figma pins the `You` row at the bottom of the screen).
class _PinnedRow extends StatelessWidget {
  const _PinnedRow({required this.entry, required this.formatTime});

  final LeaderboardEntry entry;
  final String Function(int timeMs) formatTime;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.bgCanvas,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: LeaderboardRow(
          rank: entry.rank,
          displayName: entry.displayName,
          // Spec §7: the pinned viewer row shows the literal "You", never the
          // entry's display name (which is the username against a real backend).
          nameOverride: 'You',
          time: formatTime(entry.timeMs),
          countryCode: entry.countryCode,
          isCurrentUser: true,
        ),
      ),
    );
  }
}
