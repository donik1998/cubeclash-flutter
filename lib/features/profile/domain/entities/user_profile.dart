import 'package:equatable/equatable.dart';

/// The signed-in user — `GET /me`.
class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.email,
    this.countryCode,
    this.avatarUrl,
    this.elo,
    this.bestSingleMs,
    this.bestAo5Ms,
    this.bestAo12Ms,
    this.solveCount = 0,
  });

  final String id;
  final String displayName;
  final String? email;
  final String? countryCode;
  final String? avatarUrl;

  /// Server-owned rating. Displayed, never derived.
  final int? elo;

  final int? bestSingleMs;
  final int? bestAo5Ms;
  final int? bestAo12Ms;
  final int solveCount;

  UserProfile copyWith({String? displayName, String? countryCode}) =>
      UserProfile(
        id: id,
        displayName: displayName ?? this.displayName,
        email: email,
        countryCode: countryCode ?? this.countryCode,
        avatarUrl: avatarUrl,
        elo: elo,
        bestSingleMs: bestSingleMs,
        bestAo5Ms: bestAo5Ms,
        bestAo12Ms: bestAo12Ms,
        solveCount: solveCount,
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        displayName,
        email,
        countryCode,
        avatarUrl,
        elo,
        bestSingleMs,
        bestAo5Ms,
        bestAo12Ms,
        solveCount,
      ];
}

/// Friendship state, from the `friendships.status` enum.
enum FriendStatus {
  /// They sent you a request, or you sent them one.
  pending,
  accepted;

  static FriendStatus fromWire(String? wire) =>
      wire == 'accepted' ? FriendStatus.accepted : FriendStatus.pending;
}

class Friend extends Equatable {
  const Friend({
    required this.userId,
    required this.displayName,
    required this.status,
    this.countryCode,
    this.avatarUrl,
    this.bestSingleMs,
    this.incoming = false,
  });

  final String userId;
  final String displayName;
  final FriendStatus status;
  final String? countryCode;
  final String? avatarUrl;
  final int? bestSingleMs;

  /// True when *they* invited *you* — only those can be accepted.
  final bool incoming;

  @override
  List<Object?> get props => <Object?>[
        userId,
        displayName,
        status,
        countryCode,
        avatarUrl,
        bestSingleMs,
        incoming,
      ];
}
