import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// Seeded in-memory [ProfileRepository].
class FakeProfileRepository implements ProfileRepository {
  UserProfile _me = const UserProfile(
    id: 'me',
    displayName: 'Doniyor',
    email: 'you@example.com',
    countryCode: 'GB',
    elo: 1284,
    bestSingleMs: 8420,
    bestAo5Ms: 10960,
    bestAo12Ms: 11540,
    solveCount: 142,
  );

  final List<Friend> _friends = <Friend>[
    const Friend(
      userId: 'u2',
      displayName: 'Ana Silva',
      status: FriendStatus.accepted,
      countryCode: 'BR',
      bestSingleMs: 6310,
    ),
    const Friend(
      userId: 'u5',
      displayName: 'Lukas Meyer',
      status: FriendStatus.accepted,
      countryCode: 'DE',
      bestSingleMs: 6890,
    ),
    // An incoming request, so the pending section is reachable in the demo.
    const Friend(
      userId: 'u7',
      displayName: 'Sofia Rossi',
      status: FriendStatus.pending,
      countryCode: 'IT',
      bestSingleMs: 7250,
      incoming: true,
    ),
    // And an outgoing one, which must *not* be acceptable.
    const Friend(
      userId: 'u9',
      displayName: 'Mia Andersen',
      status: FriendStatus.pending,
      countryCode: 'NO',
      bestSingleMs: 7690,
    ),
  ];

  static const Duration _latency = Duration(milliseconds: 240);

  @override
  Future<Result<UserProfile>> getMe() async {
    await Future<void>.delayed(_latency);
    return Ok<UserProfile>(_me);
  }

  @override
  Future<Result<UserProfile>> updateMe({
    String? displayName,
    String? country,
  }) async {
    await Future<void>.delayed(_latency);

    final String? name = displayName?.trim();
    if (name != null && name.isEmpty) {
      return const Err<UserProfile>(
        ServerFailure('Display name cannot be empty.'),
      );
    }

    _me = _me.copyWith(displayName: name, countryCode: country);
    return Ok<UserProfile>(_me);
  }

  @override
  Future<Result<List<Friend>>> getFriends() async {
    await Future<void>.delayed(_latency);
    return Ok<List<Friend>>(List<Friend>.unmodifiable(_friends));
  }

  @override
  Future<Result<void>> inviteFriend(String query) async {
    await Future<void>.delayed(_latency);

    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const Err<void>(ServerFailure('Enter a name or email.'));
    }
    if (_friends.any(
      (Friend f) => f.displayName.toLowerCase() == trimmed.toLowerCase(),
    )) {
      return const Err<void>(
        ServerFailure("You've already got a request with them."),
      );
    }

    _friends.add(
      Friend(
        userId: 'invited-${_friends.length}',
        displayName: trimmed,
        status: FriendStatus.pending,
      ),
    );
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> acceptFriend(String userId) async {
    await Future<void>.delayed(_latency);

    final int index = _friends.indexWhere((Friend f) => f.userId == userId);
    if (index == -1) {
      return const Err<void>(ServerFailure('That request no longer exists.'));
    }

    final Friend friend = _friends[index];
    _friends[index] = Friend(
      userId: friend.userId,
      displayName: friend.displayName,
      status: FriendStatus.accepted,
      countryCode: friend.countryCode,
      avatarUrl: friend.avatarUrl,
      bestSingleMs: friend.bestSingleMs,
    );
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> logout() async {
    await Future<void>.delayed(_latency);
    return const Ok<void>(null);
  }
}
