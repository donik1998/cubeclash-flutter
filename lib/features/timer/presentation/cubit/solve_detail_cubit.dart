import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/page.dart';
import '../../domain/entities/penalty.dart';
import '../../domain/entities/solve.dart';
import '../../domain/repositories/solve_repository.dart';

class SolveDetailState extends Equatable {
  const SolveDetailState({
    this.solveId = '',
    this.solve,
    this.isLoading = true,
    this.isSaving = false,
    this.deleted = false,
    this.failure,
  });

  final String solveId;
  final Solve? solve;
  final bool isLoading;
  final bool isSaving;

  /// Set once the delete succeeds — the view pops on this rather than the
  /// cubit reaching for a Navigator.
  final bool deleted;
  final Failure? failure;

  SolveDetailState copyWith({
    String? solveId,
    Solve? solve,
    bool? isLoading,
    bool? isSaving,
    bool? deleted,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      SolveDetailState(
        solveId: solveId ?? this.solveId,
        solve: solve ?? this.solve,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        deleted: deleted ?? this.deleted,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props =>
      <Object?>[solveId, solve, isLoading, isSaving, deleted, failure];
}

/// Backs the Solve Detail screen.
///
/// A Cubit, not a Bloc: there is no state machine here, just load / edit /
/// delete (CLAUDE.md — "Cubit for simple screens, Bloc for the timer and race
/// state machines").
class SolveDetailCubit extends Cubit<SolveDetailState> {
  SolveDetailCubit({
    required SolveRepository repository,
    required AnalyticsService analytics,
  })  : _repository = repository,
        _analytics = analytics,
        super(const SolveDetailState());

  final SolveRepository _repository;
  final AnalyticsService _analytics;

  /// Finds the solve by walking history pages.
  ///
  /// There is no documented `GET /solves/:id` (docs → API Design lists only
  /// the collection, PATCH and DELETE), so a single-solve read has to page.
  /// Bounded so a bad id cannot walk the entire history — if it isn't in the
  /// first few pages the answer is "not found" rather than an unbounded scan.
  Future<void> load(String id, {String event = '3x3'}) async {
    emit(SolveDetailState(solveId: id));

    const int maxPages = 5;
    String? cursor;

    for (int page = 0; page < maxPages; page++) {
      final Result<Page<Solve>> result =
          await _repository.getHistory(event: event, cursor: cursor);
      if (isClosed) return;

      switch (result) {
        case Err<Page<Solve>>(:final Failure failure):
          emit(state.copyWith(isLoading: false, failure: failure));
          return;

        case Ok<Page<Solve>>(:final Page<Solve> value):
          for (final Solve solve in value.items) {
            if (solve.id == id) {
              emit(state.copyWith(solve: solve, isLoading: false));
              return;
            }
          }
          if (!value.hasMore) {
            emit(state.copyWith(isLoading: false));
            return;
          }
          cursor = value.nextCursor;
      }
    }

    emit(state.copyWith(isLoading: false));
  }

  Future<void> changePenalty(Penalty penalty) async {
    final Solve? current = state.solve;
    if (current == null) return;

    // Optimistic, with rollback — the control must feel immediate.
    emit(
      state.copyWith(
        solve: current.copyWith(penalty: penalty),
        isSaving: true,
        clearFailure: true,
      ),
    );

    _analytics.capture(
      'penalty_applied',
      properties: <String, Object?>{'type': penalty.name},
    );

    final Result<Solve> result =
        await _repository.updatePenalty(current.id, penalty);
    if (isClosed) return;

    switch (result) {
      case Ok<Solve>(:final Solve value):
        emit(state.copyWith(solve: value, isSaving: false));
      case Err<Solve>(:final Failure failure):
        emit(state.copyWith(solve: current, isSaving: false, failure: failure));
    }
  }

  Future<void> delete() async {
    final Solve? current = state.solve;
    if (current == null) return;

    emit(state.copyWith(isSaving: true, clearFailure: true));

    final Result<void> result = await _repository.deleteSolve(current.id);
    if (isClosed) return;

    switch (result) {
      case Ok<void>():
        emit(state.copyWith(isSaving: false, deleted: true));
      case Err<void>(:final Failure failure):
        emit(state.copyWith(isSaving: false, failure: failure));
    }
  }
}
