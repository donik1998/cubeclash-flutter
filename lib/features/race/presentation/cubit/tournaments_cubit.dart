import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/repositories/tournament_repository.dart';

class TournamentsState extends Equatable {
  const TournamentsState({
    this.isLoading = true,
    this.tournaments = const <Tournament>[],
    this.registeringId,
    this.failure,
  });

  final bool isLoading;
  final List<Tournament> tournaments;

  /// The tournament a register call is in flight for, so just its button spins.
  final String? registeringId;
  final Failure? failure;

  bool get isEmpty => !isLoading && failure == null && tournaments.isEmpty;

  TournamentsState copyWith({
    bool? isLoading,
    List<Tournament>? tournaments,
    String? registeringId,
    bool clearRegistering = false,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      TournamentsState(
        isLoading: isLoading ?? this.isLoading,
        tournaments: tournaments ?? this.tournaments,
        registeringId:
            clearRegistering ? null : (registeringId ?? this.registeringId),
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props =>
      <Object?>[isLoading, tournaments, registeringId, failure];
}

class TournamentsCubit extends Cubit<TournamentsState> {
  TournamentsCubit({required TournamentRepository repository})
      : _repository = repository,
        super(const TournamentsState());

  final TournamentRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final Result<List<Tournament>> result = await _repository.getTournaments();
    if (isClosed) return;

    switch (result) {
      case Ok<List<Tournament>>(:final List<Tournament> value):
        emit(state.copyWith(isLoading: false, tournaments: value));
      case Err<List<Tournament>>(:final Failure failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  Future<void> register(String id) async {
    emit(state.copyWith(registeringId: id, clearFailure: true));

    final Result<void> result = await _repository.register(id);
    if (isClosed) return;

    switch (result) {
      case Ok<void>():
        // Reflect the entry locally; the server owns the real count.
        final List<Tournament> updated = <Tournament>[
          for (final Tournament t in state.tournaments)
            if (t.id == id)
              t.copyWith(registered: true, entrants: t.entrants + 1)
            else
              t,
        ];
        emit(state.copyWith(tournaments: updated, clearRegistering: true));
      case Err<void>(:final Failure failure):
        emit(state.copyWith(clearRegistering: true, failure: failure));
    }
  }
}

class TournamentDetailState extends Equatable {
  const TournamentDetailState({
    this.isLoading = true,
    this.detail,
    this.failure,
  });

  final bool isLoading;
  final TournamentDetail? detail;
  final Failure? failure;

  TournamentDetailState copyWith({
    bool? isLoading,
    TournamentDetail? detail,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      TournamentDetailState(
        isLoading: isLoading ?? this.isLoading,
        detail: detail ?? this.detail,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => <Object?>[isLoading, detail, failure];
}

class TournamentDetailCubit extends Cubit<TournamentDetailState> {
  TournamentDetailCubit({required TournamentRepository repository})
      : _repository = repository,
        super(const TournamentDetailState());

  final TournamentRepository _repository;

  Future<void> load(String id) async {
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final Result<TournamentDetail> result = await _repository.getTournament(id);
    if (isClosed) return;

    switch (result) {
      case Ok<TournamentDetail>(:final TournamentDetail value):
        emit(state.copyWith(isLoading: false, detail: value));
      case Err<TournamentDetail>(:final Failure failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }
}
