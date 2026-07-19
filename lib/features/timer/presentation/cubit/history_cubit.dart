import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/page.dart';
import '../../domain/entities/solve.dart';
import '../../domain/repositories/solve_repository.dart';
import '../../domain/usecases/compute_averages.dart';

class HistoryState extends Equatable {
  const HistoryState({
    this.event = '3x3',
    this.solves = const <Solve>[],
    this.nextCursor,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.failure,
  });

  final String event;

  /// Newest first, as `GET /solves` returns them.
  final List<Solve> solves;
  final String? nextCursor;

  /// First load only. Paging appends without blanking the list.
  final bool isLoading;
  final bool isLoadingMore;
  final Failure? failure;

  bool get hasMore => nextCursor != null;
  bool get isEmpty => !isLoading && failure == null && solves.isEmpty;

  /// Solves grouped by calendar day, newest day first — history reads as
  /// "what did I do on Tuesday", not as one undifferentiated list.
  List<({DateTime day, List<Solve> solves})> get byDay {
    final Map<DateTime, List<Solve>> groups = <DateTime, List<Solve>>{};
    for (final Solve solve in solves) {
      final DateTime day = DateTime(
        solve.solvedAt.year,
        solve.solvedAt.month,
        solve.solvedAt.day,
      );
      groups.putIfAbsent(day, () => <Solve>[]).add(solve);
    }

    final List<DateTime> days = groups.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));

    return <({DateTime day, List<Solve> solves})>[
      for (final DateTime day in days) (day: day, solves: groups[day]!),
    ];
  }

  HistoryState copyWith({
    String? event,
    List<Solve>? solves,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      HistoryState(
        event: event ?? this.event,
        solves: solves ?? this.solves,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => <Object?>[
        event,
        solves,
        nextCursor,
        isLoading,
        isLoadingMore,
        failure,
      ];
}

/// Backs Session & History — a paginated list plus the current session's
/// summary stats.
class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit({required SolveRepository repository})
      : _repository = repository,
        super(const HistoryState());

  final SolveRepository _repository;

  static const ComputeAverages _averages = ComputeAverages();

  Future<void> load({String event = '3x3'}) async {
    emit(HistoryState(event: event));

    final Result<Page<Solve>> result =
        await _repository.getHistory(event: event);
    if (isClosed) return;

    switch (result) {
      case Ok<Page<Solve>>(:final Page<Solve> value):
        emit(
          state.copyWith(
            solves: value.items,
            nextCursor: value.nextCursor,
            clearCursor: value.nextCursor == null,
            isLoading: false,
          ),
        );
      case Err<Page<Solve>>(:final Failure failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  /// Appends the next page. Guarded so a fast scroll can't fire overlapping
  /// requests and duplicate rows.
  Future<void> loadMore() async {
    final String? cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore || state.isLoading) return;

    emit(state.copyWith(isLoadingMore: true));

    final Result<Page<Solve>> result =
        await _repository.getHistory(event: state.event, cursor: cursor);
    if (isClosed) return;

    switch (result) {
      case Ok<Page<Solve>>(:final Page<Solve> value):
        emit(
          state.copyWith(
            solves: <Solve>[...state.solves, ...value.items],
            nextCursor: value.nextCursor,
            clearCursor: value.nextCursor == null,
            isLoadingMore: false,
          ),
        );
      case Err<Page<Solve>>(:final Failure failure):
        // Keep what's already loaded; only the append failed.
        emit(state.copyWith(isLoadingMore: false, failure: failure));
    }
  }

  Future<void> clearSession() async {
    final Result<void> result = await _repository.clearSession();
    if (isClosed) return;

    if (result case Err<void>(:final Failure failure)) {
      emit(state.copyWith(failure: failure));
    }
  }

  /// Stats over the solves currently loaded.
  ///
  /// Averages need the *chronological* order [ComputeAverages] expects
  /// ("most recent n"), but the list is newest-first — hence the reverse.
  ({int? best, int? ao5, int? ao12}) statsFor(List<Solve> solves) {
    final List<int?> times = solves.reversed
        .map((Solve s) => s.effectiveTimeMs)
        .toList(growable: false);

    final List<int> valid = times.whereType<int>().toList()..sort();

    return (
      best: valid.isEmpty ? null : valid.first,
      ao5: _averages.average(times, 5),
      ao12: _averages.average(times, 12),
    );
  }
}
