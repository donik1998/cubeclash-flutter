import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class FriendsState extends Equatable {
  const FriendsState({
    this.friends = const <Friend>[],
    this.isLoading = true,
    this.isSubmitting = false,
    this.failure,
    this.inviteSent = false,
  });

  final List<Friend> friends;
  final bool isLoading;
  final bool isSubmitting;
  final Failure? failure;

  /// One-shot flag so the view can confirm and reset the invite field.
  final bool inviteSent;

  /// Requests *they* sent *you* — the only ones with an Accept button.
  List<Friend> get incomingRequests => friends
      .where((Friend f) => f.status == FriendStatus.pending && f.incoming)
      .toList();

  /// Invitations you've sent that haven't been answered.
  List<Friend> get outgoingRequests => friends
      .where((Friend f) => f.status == FriendStatus.pending && !f.incoming)
      .toList();

  List<Friend> get accepted =>
      friends.where((Friend f) => f.status == FriendStatus.accepted).toList();

  bool get isEmpty => !isLoading && failure == null && friends.isEmpty;

  FriendsState copyWith({
    List<Friend>? friends,
    bool? isLoading,
    bool? isSubmitting,
    bool? inviteSent,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      FriendsState(
        friends: friends ?? this.friends,
        isLoading: isLoading ?? this.isLoading,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        inviteSent: inviteSent ?? this.inviteSent,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props =>
      <Object?>[friends, isLoading, isSubmitting, failure, inviteSent];
}

class FriendsCubit extends Cubit<FriendsState> {
  FriendsCubit({required ProfileRepository repository})
      : _repository = repository,
        super(const FriendsState());

  final ProfileRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final Result<List<Friend>> result = await _repository.getFriends();
    if (isClosed) return;

    switch (result) {
      case Ok<List<Friend>>(:final List<Friend> value):
        emit(state.copyWith(friends: value, isLoading: false));
      case Err<List<Friend>>(:final Failure failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  Future<void> invite(String query) async {
    emit(
      state.copyWith(
        isSubmitting: true,
        inviteSent: false,
        clearFailure: true,
      ),
    );

    final Result<void> result = await _repository.inviteFriend(query);
    if (isClosed) return;

    switch (result) {
      case Ok<void>():
        emit(state.copyWith(isSubmitting: false, inviteSent: true));
        // Refresh so the new pending row appears.
        await load();
      case Err<void>(:final Failure failure):
        emit(state.copyWith(isSubmitting: false, failure: failure));
    }
  }

  Future<void> accept(String userId) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final Result<void> result = await _repository.acceptFriend(userId);
    if (isClosed) return;

    switch (result) {
      case Ok<void>():
        emit(state.copyWith(isSubmitting: false));
        await load();
      case Err<void>(:final Failure failure):
        emit(state.copyWith(isSubmitting: false, failure: failure));
    }
  }

  /// Clears the one-shot confirmation once the view has acted on it.
  void acknowledgeInvite() => emit(state.copyWith(inviteSent: false));
}
