import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/lobby_summary.dart';
import '../../domain/repositories/race_lobby_repository.dart';

class LobbyState extends Equatable {
  const LobbyState({this.summary, this.isLoading = true, this.failure});

  final LobbySummary? summary;
  final bool isLoading;
  final Failure? failure;

  LobbyState copyWith({
    LobbySummary? summary,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      LobbyState(
        summary: summary ?? this.summary,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => <Object?>[summary, isLoading, failure];
}

/// Loads the lobby's Elo / stats / rivals summary. A failure is non-fatal — the
/// lobby's core actions (find a match, create a room) don't depend on it, so
/// the header and stats row just stay quiet.
class LobbyCubit extends Cubit<LobbyState> {
  LobbyCubit({required RaceLobbyRepository repository})
      : _repository = repository,
        super(const LobbyState());

  final RaceLobbyRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final Result<LobbySummary> result = await _repository.summary();
    if (isClosed) return;

    switch (result) {
      case Ok<LobbySummary>(:final LobbySummary value):
        emit(state.copyWith(isLoading: false, summary: value));
      case Err<LobbySummary>(:final Failure failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }
}
