import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/auth_repository.dart';

/// Field-level validation, kept out of the widgets so it can be tested without
/// pumping one.
class AuthValidators {
  const AuthValidators._();

  /// Deliberately permissive: "has an @ with something either side, and a dot
  /// after it". Anything stricter rejects valid addresses, and the server is
  /// the real authority anyway.
  static String? email(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter your email.';
    final RegExp pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(trimmed)) return "That doesn't look like an email.";
    return null;
  }

  /// Length only. Composition rules ("one symbol, one digit") push people
  /// toward shorter, more predictable passwords; length is what matters.
  static String? password(String value) {
    if (value.isEmpty) return 'Enter a password.';
    if (value.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  static String? displayName(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return 'Pick a display name.';
    if (trimmed.length < 2) return 'That is a little short.';
    if (trimmed.length > 24) return 'Keep it under 24 characters.';
    return null;
  }
}

class AuthState extends Equatable {
  const AuthState({
    this.isSubmitting = false,
    this.succeeded = false,
    this.needsProfileSetup = false,
    this.failure,
  });

  final bool isSubmitting;

  /// The flow finished — the view navigates on this.
  final bool succeeded;

  /// Registration succeeded but the profile-setup step hasn't run yet.
  final bool needsProfileSetup;

  final Failure? failure;

  AuthState copyWith({
    bool? isSubmitting,
    bool? succeeded,
    bool? needsProfileSetup,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      AuthState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        succeeded: succeeded ?? this.succeeded,
        needsProfileSetup: needsProfileSetup ?? this.needsProfileSetup,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props =>
      <Object?>[isSubmitting, succeeded, needsProfileSetup, failure];
}

/// Drives sign-up, log-in and profile setup.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required AuthRepository repository})
      : _repository = repository,
        super(const AuthState());

  final AuthRepository _repository;

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final Result<void> result = await _repository.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    if (isClosed) return;

    switch (result) {
      case Ok<void>():
        // A new account goes to profile setup, not straight into the shell —
        // country is asked for once, here, rather than nagged for later.
        emit(state.copyWith(isSubmitting: false, needsProfileSetup: true));
      case Err<void>(:final Failure failure):
        emit(state.copyWith(isSubmitting: false, failure: failure));
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final Result<void> result =
        await _repository.login(email: email, password: password);
    if (isClosed) return;

    switch (result) {
      case Ok<void>():
        emit(state.copyWith(isSubmitting: false, succeeded: true));
      case Err<void>(:final Failure failure):
        emit(state.copyWith(isSubmitting: false, failure: failure));
    }
  }

  Future<void> completeProfile({
    required String displayName,
    String? country,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final Result<void> result = await _repository.completeProfile(
      displayName: displayName,
      country: country,
    );
    if (isClosed) return;

    switch (result) {
      case Ok<void>():
        emit(state.copyWith(isSubmitting: false, succeeded: true));
      case Err<void>(:final Failure failure):
        emit(state.copyWith(isSubmitting: false, failure: failure));
    }
  }

  void dismissFailure() => emit(state.copyWith(clearFailure: true));
}
