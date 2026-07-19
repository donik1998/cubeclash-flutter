import 'package:dio/dio.dart';

import '../../../../core/error/result.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_failures.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// The real [ProfileRepository].
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._client, this._tokens);

  final DioClient _client;
  final TokenStore _tokens;

  @override
  Future<Result<UserProfile>> getMe() => Result.guard<UserProfile>(
        () async {
          final Response<dynamic> response =
              await _client.dio.get<dynamic>('/me');
          return _profileFromJson(unwrap(response.data, 'user'));
        },
        onError: dioFailure,
      );

  @override
  Future<Result<UserProfile>> updateMe({
    String? displayName,
    String? country,
  }) =>
      Result.guard<UserProfile>(
        () async {
          final Response<dynamic> response = await _client.dio.patch<dynamic>(
            '/me',
            // Only send what changed — PATCH semantics, and it avoids
            // clobbering a field the user didn't touch.
            data: <String, dynamic>{
              if (displayName != null) 'display_name': displayName,
              if (country != null) 'country': country,
            },
          );
          return _profileFromJson(unwrap(response.data, 'user'));
        },
        onError: dioFailure,
      );

  @override
  Future<Result<List<Friend>>> getFriends() => Result.guard<List<Friend>>(
        () async {
          final Response<dynamic> response =
              await _client.dio.get<dynamic>('/friends');
          final Map<String, dynamic> body = asJsonMap(response.data);
          final List<dynamic> items =
              (body['items'] as List<dynamic>?) ?? <dynamic>[];

          return <Friend>[
            for (final dynamic f in items) _friendFromJson(asJsonMap(f)),
          ];
        },
        onError: dioFailure,
      );

  @override
  Future<Result<void>> inviteFriend(String query) => Result.guard<void>(
        () => _client.dio.post<dynamic>(
          '/friends/invite',
          data: <String, dynamic>{'query': query.trim()},
        ),
        onError: dioFailure,
      );

  @override
  Future<Result<void>> acceptFriend(String userId) => Result.guard<void>(
        () => _client.dio.post<dynamic>('/friends/$userId/accept'),
        onError: dioFailure,
      );

  @override
  Future<Result<void>> logout() async {
    // Tell the server first so it can revoke the refresh token…
    final Result<void> result = await Result.guard<void>(
      () => _client.dio.post<dynamic>('/auth/logout'),
      onError: dioFailure,
    );
    // …but clear locally regardless. A logout that leaves you signed in
    // because the network was down is the worse failure.
    _tokens.clear();
    return result;
  }

  static UserProfile _profileFromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        email: json['email'] as String?,
        countryCode: json['country'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        elo: _int(json['elo']),
        bestSingleMs: _int(json['best_single_ms']),
        bestAo5Ms: _int(json['best_ao5_ms']),
        bestAo12Ms: _int(json['best_ao12_ms']),
        solveCount: _int(json['solve_count']) ?? 0,
      );

  static Friend _friendFromJson(Map<String, dynamic> json) => Friend(
        userId: json['user_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? 'Unknown',
        status: FriendStatus.fromWire(json['status'] as String?),
        countryCode: json['country'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        bestSingleMs: _int(json['best_single_ms']),
        incoming: json['incoming'] as bool? ?? false,
      );

  static int? _int(dynamic v) => v is num ? v.toInt() : null;
}
