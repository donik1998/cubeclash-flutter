import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.profile,
    this.isLoading = true,
    this.isSaving = false,
    this.signedOut = false,
    this.failure,
  });

  final UserProfile? profile;
  final bool isLoading;
  final bool isSaving;

  /// Set once logout completes; the view redirects on it rather than the cubit
  /// reaching for a router.
  final bool signedOut;
  final Failure? failure;

  ProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
    bool? isSaving,
    bool? signedOut,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      ProfileState(
        profile: profile ?? this.profile,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        signedOut: signedOut ?? this.signedOut,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props =>
      <Object?>[profile, isLoading, isSaving, signedOut, failure];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required ProfileRepository repository})
      : _repository = repository,
        super(const ProfileState());

  final ProfileRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final Result<UserProfile> result = await _repository.getMe();
    if (isClosed) return;

    switch (result) {
      case Ok<UserProfile>(:final UserProfile value):
        emit(state.copyWith(profile: value, isLoading: false));
      case Err<UserProfile>(:final Failure failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  Future<void> updateProfile({String? displayName, String? country}) async {
    emit(state.copyWith(isSaving: true, clearFailure: true));

    final Result<UserProfile> result = await _repository.updateMe(
      displayName: displayName,
      country: country,
    );
    if (isClosed) return;

    switch (result) {
      case Ok<UserProfile>(:final UserProfile value):
        emit(state.copyWith(profile: value, isSaving: false));
      case Err<UserProfile>(:final Failure failure):
        emit(state.copyWith(isSaving: false, failure: failure));
    }
  }

  Future<void> logout() async {
    emit(state.copyWith(isSaving: true, clearFailure: true));

    // The repository clears local tokens whatever the server says, so the user
    // is signed out either way — reporting failure here would be a lie.
    await _repository.logout();
    if (isClosed) return;

    emit(state.copyWith(isSaving: false, signedOut: true));
  }
}
