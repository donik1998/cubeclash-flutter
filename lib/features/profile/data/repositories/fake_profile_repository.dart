import 'dart:math';

import '../../../../core/demo/demo_seed.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/badge.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// Seeded in-memory [ProfileRepository].
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({Random? random, double readFailureRate = 0})
      : _random = random ?? Random(13),
        _readFailureRate = readFailureRate;

  final Random _random;

  /// How often a read pretends the network failed, so the error states are
  /// reachable in a demo. Defaults to 0; wire a small value in DI to show it.
  final double _readFailureRate;

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

  Future<void> _wait() => Future<void>.delayed(demoLatency(_latency, _random));

  bool get _readFails => _random.nextDouble() < _readFailureRate;

  @override
  Future<Result<UserProfile>> getMe() async {
    await _wait();
    if (_readFails) {
      return const Err<UserProfile>(
        NetworkFailure('Something went wrong. Pull to retry.'),
      );
    }
    return Ok<UserProfile>(_me);
  }

  @override
  Future<Result<UserProfile>> updateMe({
    String? displayName,
    String? country,
  }) async {
    await _wait();

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
    await _wait();
    if (_readFails) {
      return const Err<List<Friend>>(
        NetworkFailure('Something went wrong. Pull to retry.'),
      );
    }
    return Ok<List<Friend>>(List<Friend>.unmodifiable(_friends));
  }

  @override
  Future<Result<List<Badge>>> getBadges() async {
    await _wait();
    if (_readFails) {
      return const Err<List<Badge>>(
        NetworkFailure('Something went wrong. Pull to retry.'),
      );
    }
    return const Ok<List<Badge>>(_badges);
  }

  /// A plausible achievement set — five earned, three still to chase — so the
  /// profile's badge row is real rather than three grey circles.
  static const List<Badge> _badges = <Badge>[
    Badge(
      id: 'first-solve',
      name: 'First Solve',
      description: 'Recorded your very first solve.',
      icon: BadgeIcon.firstSolve,
      earned: true,
    ),
    Badge(
      id: 'sub-15',
      name: 'Sub-15',
      description: 'Broke fifteen seconds on a 3×3 single.',
      icon: BadgeIcon.speed,
      earned: true,
    ),
    Badge(
      id: 'century',
      name: 'Century',
      description: 'Logged one hundred solves.',
      icon: BadgeIcon.milestone,
      earned: true,
    ),
    Badge(
      id: 'first-blood',
      name: 'First Blood',
      description: 'Won your first live race.',
      icon: BadgeIcon.race,
      earned: true,
    ),
    Badge(
      id: 'contender',
      name: 'Contender',
      description: 'Reached the global top 50.',
      icon: BadgeIcon.podium,
      earned: true,
    ),
    Badge(
      id: 'week-streak',
      name: 'On a Roll',
      description: 'Solve every day for a week.',
      icon: BadgeIcon.streak,
      earned: false,
      progressLabel: '5/7 days',
    ),
    Badge(
      id: 'explorer',
      name: 'Explorer',
      description: 'Time a solve in all seventeen events.',
      icon: BadgeIcon.allEvents,
      earned: false,
      progressLabel: '12/17 events',
    ),
    Badge(
      id: 'comeback',
      name: 'Comeback',
      description: 'Win a race after falling two seconds behind.',
      icon: BadgeIcon.comeback,
      earned: false,
    ),
  ];

  @override
  Future<Result<void>> inviteFriend(String query) async {
    await _wait();

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
    await _wait();

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
    await _wait();
    return const Ok<void>(null);
  }
}
