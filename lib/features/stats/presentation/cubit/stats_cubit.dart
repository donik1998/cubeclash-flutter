import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/player_stats.dart';
import '../../domain/repositories/stats_repository.dart';

/// Which half of the Stats tab is showing.
enum StatsSegment { myStats, leaderboards }

class StatsState extends Equatable {
  const StatsState({
    this.segment = StatsSegment.myStats,
    this.event = '3x3',
    this.stats,
    this.isLoadingStats = true,
    this.statsFailure,
    this.leaderboard,
    this.metric = LeaderboardMetric.single,
    this.scope = LeaderboardScope.global,
    this.isLoadingLeaderboard = true,
    this.isLoadingMore = false,
    this.leaderboardFailure,
  });

  final StatsSegment segment;
  final String event;

  // --- My Stats ---
  final PlayerStats? stats;
  final bool isLoadingStats;
  final Failure? statsFailure;

  // --- Leaderboards ---
  final Leaderboard? leaderboard;
  final LeaderboardMetric metric;
  final LeaderboardScope scope;
  final bool isLoadingLeaderboard;
  final bool isLoadingMore;
  final Failure? leaderboardFailure;

  /// No solves yet — the charts have nothing to say.
  bool get statsEmpty =>
      !isLoadingStats && statsFailure == null && (stats?.solveCount ?? 0) == 0;

  /// Some solves, but too few for a trend to mean anything.
  bool get statsTooThin =>
      !isLoadingStats &&
      statsFailure == null &&
      stats != null &&
      stats!.solveCount > 0 &&
      !stats!.hasEnoughForCharts;

  bool get leaderboardEmpty =>
      !isLoadingLeaderboard &&
      leaderboardFailure == null &&
      (leaderboard?.entries.isEmpty ?? true);

  /// Show the viewer's own row pinned at the bottom only when it isn't already
  /// on screen.
  LeaderboardEntry? get pinnedViewer {
    final Leaderboard? board = leaderboard;
    if (board == null || board.viewerVisible) return null;
    return board.viewer;
  }

  StatsState copyWith({
    StatsSegment? segment,
    String? event,
    PlayerStats? stats,
    bool? isLoadingStats,
    Failure? statsFailure,
    bool clearStatsFailure = false,
    Leaderboard? leaderboard,
    bool clearLeaderboard = false,
    LeaderboardMetric? metric,
    LeaderboardScope? scope,
    bool? isLoadingLeaderboard,
    bool? isLoadingMore,
    Failure? leaderboardFailure,
    bool clearLeaderboardFailure = false,
  }) =>
      StatsState(
        segment: segment ?? this.segment,
        event: event ?? this.event,
        stats: stats ?? this.stats,
        isLoadingStats: isLoadingStats ?? this.isLoadingStats,
        statsFailure:
            clearStatsFailure ? null : (statsFailure ?? this.statsFailure),
        leaderboard:
            clearLeaderboard ? null : (leaderboard ?? this.leaderboard),
        metric: metric ?? this.metric,
        scope: scope ?? this.scope,
        isLoadingLeaderboard: isLoadingLeaderboard ?? this.isLoadingLeaderboard,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        leaderboardFailure: clearLeaderboardFailure
            ? null
            : (leaderboardFailure ?? this.leaderboardFailure),
      );

  @override
  List<Object?> get props => <Object?>[
        segment,
        event,
        stats,
        isLoadingStats,
        statsFailure,
        leaderboard,
        metric,
        scope,
        isLoadingLeaderboard,
        isLoadingMore,
        leaderboardFailure,
      ];
}

/// Backs both segments of the Stats tab.
///
/// One cubit rather than two so switching segments doesn't refetch what's
/// already loaded — each half keeps its own loading/error state.
class StatsCubit extends Cubit<StatsState> {
  StatsCubit({
    required StatsRepository repository,
    required AnalyticsService analytics,
  })  : _repository = repository,
        _analytics = analytics,
        super(const StatsState());

  final StatsRepository _repository;
  final AnalyticsService _analytics;

  /// Loads whichever segment the user lands on. The other loads lazily when
  /// they switch, so opening Stats costs one request, not two.
  Future<void> start() => loadStats();

  void selectSegment(StatsSegment segment) {
    if (segment == state.segment) return;
    emit(state.copyWith(segment: segment));

    _analytics.capture(
      'stats_viewed',
      properties: <String, Object?>{'segment': segment.name},
    );

    if (segment == StatsSegment.leaderboards && state.leaderboard == null) {
      loadLeaderboard();
    }
    if (segment == StatsSegment.myStats && state.stats == null) {
      loadStats();
    }
  }

  Future<void> loadStats() async {
    emit(state.copyWith(isLoadingStats: true, clearStatsFailure: true));

    final Result<PlayerStats> result =
        await _repository.getStats(event: state.event);
    if (isClosed) return;

    switch (result) {
      case Ok<PlayerStats>(:final PlayerStats value):
        emit(state.copyWith(stats: value, isLoadingStats: false));
      case Err<PlayerStats>(:final Failure failure):
        emit(state.copyWith(isLoadingStats: false, statsFailure: failure));
    }
  }

  Future<void> changeEvent(String event) async {
    if (event == state.event) return;
    // Both halves are event-scoped, so both are now stale.
    emit(
      StatsState(
        segment: state.segment,
        event: event,
        metric: state.metric,
        scope: state.scope,
      ),
    );
    await loadStats();
    if (state.segment == StatsSegment.leaderboards) await loadLeaderboard();
  }

  Future<void> loadLeaderboard() async {
    emit(
      state.copyWith(
        isLoadingLeaderboard: true,
        clearLeaderboardFailure: true,
      ),
    );

    _analytics.capture(
      'leaderboard_viewed',
      properties: <String, Object?>{
        'scope': state.scope.name,
        'event': state.event,
        'metric': state.metric.name,
      },
    );

    final Result<Leaderboard> result = await _repository.getLeaderboard(
      event: state.event,
      metric: state.metric,
      scope: state.scope,
    );
    if (isClosed) return;

    switch (result) {
      case Ok<Leaderboard>(:final Leaderboard value):
        emit(state.copyWith(leaderboard: value, isLoadingLeaderboard: false));
      case Err<Leaderboard>(:final Failure failure):
        emit(
          state.copyWith(
            isLoadingLeaderboard: false,
            leaderboardFailure: failure,
          ),
        );
    }
  }

  Future<void> loadMoreLeaderboard() async {
    final Leaderboard? board = state.leaderboard;
    final String? cursor = board?.nextCursor;
    if (cursor == null || state.isLoadingMore || state.isLoadingLeaderboard) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    final Result<Leaderboard> result = await _repository.getLeaderboard(
      event: state.event,
      metric: state.metric,
      scope: state.scope,
      cursor: cursor,
    );
    if (isClosed) return;

    switch (result) {
      case Ok<Leaderboard>(:final Leaderboard value):
        emit(
          state.copyWith(
            leaderboard: Leaderboard(
              entries: <LeaderboardEntry>[...board!.entries, ...value.entries],
              // A page that omits `viewer` must not drop the one we already have.
              viewer: value.viewer ?? board.viewer,
              nextCursor: value.nextCursor,
            ),
            isLoadingMore: false,
          ),
        );
      case Err<Leaderboard>(:final Failure failure):
        emit(
          state.copyWith(isLoadingMore: false, leaderboardFailure: failure),
        );
    }
  }

  Future<void> changeMetric(LeaderboardMetric metric) async {
    if (metric == state.metric) return;
    // Changing the metric invalidates the loaded page entirely.
    emit(state.copyWith(metric: metric, clearLeaderboard: true));
    await loadLeaderboard();
  }

  Future<void> changeScope(LeaderboardScope scope) async {
    if (scope == state.scope) return;
    emit(state.copyWith(scope: scope, clearLeaderboard: true));
    await loadLeaderboard();
  }
}
