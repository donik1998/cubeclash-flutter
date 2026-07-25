import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/badge.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.profile,
    this.badges = const <Badge>[],
    this.isLoading = true,
    this.isSaving = false,
    this.signedOut = false,
    this.failure,
  });

  final UserProfile? profile;

  /// Loaded alongside the profile. A badge fetch that fails is not fatal — the
  /// profile still renders — so it degrades to an empty list, not an error.
  final List<Badge> badges;
  final bool isLoading;
  final bool isSaving;

  /// Set once logout completes; the view redirects on it rather than the cubit
  /// reaching for a router.
  final bool signedOut;
  final Failure? failure;

  ProfileState copyWith({
    UserProfile? profile,
    List<Badge>? badges,
    bool? isLoading,
    bool? isSaving,
    bool? signedOut,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      ProfileState(
        profile: profile ?? this.profile,
        badges: badges ?? this.badges,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        signedOut: signedOut ?? this.signedOut,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props =>
      <Object?>[profile, badges, isLoading, isSaving, signedOut, failure];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required ProfileRepository repository})
      : _repository = repository,
        super(const ProfileState());

  final ProfileRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));

    // Profile and badges load together; the profile decides the screen's
    // fate, so badges are read but their failure only empties the badge row.
    final (Result<UserProfile>, Result<List<Badge>>) results = await (
      _repository.getMe(),
      _repository.getBadges(),
    ).wait;
    if (isClosed) return;

    final List<Badge> badges = switch (results.$2) {
      Ok<List<Badge>>(:final List<Badge> value) => value,
      Err<List<Badge>>() => const <Badge>[],
    };

    switch (results.$1) {
      case Ok<UserProfile>(:final UserProfile value):
        emit(state.copyWith(profile: value, badges: badges, isLoading: false));
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
