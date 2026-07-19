import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/stats_repository.dart';

class PlayerProfileState extends Equatable {
  const PlayerProfileState({
    this.userId = '',
    this.profile,
    this.isLoading = true,
    this.failure,
  });

  final String userId;
  final PlayerProfile? profile;
  final bool isLoading;
  final Failure? failure;

  @override
  List<Object?> get props => <Object?>[userId, profile, isLoading, failure];
}

class PlayerProfileCubit extends Cubit<PlayerProfileState> {
  PlayerProfileCubit({required StatsRepository repository})
      : _repository = repository,
        super(const PlayerProfileState());

  final StatsRepository _repository;

  Future<void> load(String userId) async {
    emit(PlayerProfileState(userId: userId));

    final Result<PlayerProfile> result = await _repository.getPlayer(userId);
    if (isClosed) return;

    switch (result) {
      case Ok<PlayerProfile>(:final PlayerProfile value):
        emit(PlayerProfileState(
            userId: userId, profile: value, isLoading: false));
      case Err<PlayerProfile>(:final Failure failure):
        emit(
          PlayerProfileState(
            userId: userId,
            isLoading: false,
            failure: failure,
          ),
        );
    }
  }
}
