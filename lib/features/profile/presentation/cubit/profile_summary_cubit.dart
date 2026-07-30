import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/profile_summary.dart';
import '../../domain/repositories/profile_summary_repository.dart';

class ProfileSummaryState extends Equatable {
  const ProfileSummaryState({
    this.summary,
    this.isLoading = true,
    this.failure,
  });

  final ProfileSummary? summary;
  final bool isLoading;
  final Failure? failure;

  ProfileSummaryState copyWith({
    ProfileSummary? summary,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      ProfileSummaryState(
        summary: summary ?? this.summary,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => <Object?>[summary, isLoading, failure];
}

/// Drives the "You · Profile" screen off `GET /me/profile`.
class ProfileSummaryCubit extends Cubit<ProfileSummaryState> {
  ProfileSummaryCubit({
    required ProfileSummaryRepository repository,
    String event = '3x3',
    String rankScope = 'global',
  })  : _repository = repository,
        _event = event,
        _rankScope = rankScope,
        super(const ProfileSummaryState());

  final ProfileSummaryRepository _repository;
  final String _event;
  final String _rankScope;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final Result<ProfileSummary> result = await _repository.getProfileSummary(
      event: _event,
      rankScope: _rankScope,
    );
    if (isClosed) return;

    switch (result) {
      case Ok<ProfileSummary>(:final ProfileSummary value):
        emit(state.copyWith(summary: value, isLoading: false));
      case Err<ProfileSummary>(:final Failure failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  /// Re-run the fetch after a failure. Same path as [load].
  Future<void> retry() => load();
}
