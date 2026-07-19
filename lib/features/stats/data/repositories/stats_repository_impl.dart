import 'package:dio/dio.dart';

import '../../../../core/error/result.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_failures.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/player_stats.dart';
import '../../domain/repositories/stats_repository.dart';

/// The real [StatsRepository].
///
/// Written against the documented endpoints (docs → API Design § Stats &
/// leaderboards) ahead of the backend existing. Two caveats worth being honest
/// about, both flagged in the vault digest as gaps:
///
///  * `GET /stats` is documented only by prose ("best, ao5/ao12/ao100, per-source
///    averages, distribution, efficiency index") with no field names. The
///    `snake_case` keys parsed below are this client's proposal; the server
///    should be built to match, or these change.
///  * `GET /leaderboard` has no documented row shape either. Same deal.
///
/// Parsing is deliberately lenient — a missing optional key yields `null`
/// rather than an exception, so a partially-implemented endpoint degrades to a
/// screen with em-dashes instead of a crash.
class StatsRepositoryImpl implements StatsRepository {
  StatsRepositoryImpl(this._client);

  final DioClient _client;

  @override
  Future<Result<PlayerStats>> getStats({String event = '3x3'}) =>
      Result.guard<PlayerStats>(
        () async {
          final Response<dynamic> response = await _client.dio.get<dynamic>(
            '/stats',
            queryParameters: <String, dynamic>{'event': event},
          );
          return _statsFromJson(asJsonMap(response.data), event);
        },
        onError: dioFailure,
      );

  @override
  Future<Result<Leaderboard>> getLeaderboard({
    String event = '3x3',
    LeaderboardMetric metric = LeaderboardMetric.single,
    LeaderboardScope scope = LeaderboardScope.global,
    String? cursor,
  }) =>
      Result.guard<Leaderboard>(
        () async {
          final Response<dynamic> response = await _client.dio.get<dynamic>(
            '/leaderboard',
            queryParameters: <String, dynamic>{
              'event': event,
              'metric': metric.wire,
              'scope': scope.wire,
              if (cursor != null) 'cursor': cursor,
            },
          );

          final Map<String, dynamic> body = asJsonMap(response.data);
          final List<dynamic> items =
              (body['items'] as List<dynamic>?) ?? <dynamic>[];
          final dynamic me = body['current_user'];

          return Leaderboard(
            entries:
                items.map((dynamic e) => _entryFromJson(asJsonMap(e))).toList(),
            currentUser: me is Map
                ? _entryFromJson(asJsonMap(me), isCurrentUser: true)
                : null,
            nextCursor: body['next_cursor'] as String?,
          );
        },
        onError: dioFailure,
      );

  @override
  Future<Result<PlayerProfile>> getPlayer(String userId) =>
      Result.guard<PlayerProfile>(
        () async {
          final Response<dynamic> response =
              await _client.dio.get<dynamic>('/users/$userId');
          return _profileFromJson(unwrap(response.data, 'user'));
        },
        onError: dioFailure,
      );

  // --- Parsing ---------------------------------------------------------------

  static PlayerStats _statsFromJson(Map<String, dynamic> json, String event) {
    return PlayerStats(
      event: json['event'] as String? ?? event,
      solveCount: _int(json['solve_count']) ?? 0,
      bestSingleMs: _int(json['best_single_ms']),
      bestAo5Ms: _int(json['best_ao5_ms']),
      bestAo12Ms: _int(json['best_ao12_ms']),
      bestAo100Ms: _int(json['best_ao100_ms']),
      progress: <StatsPoint>[
        for (final dynamic p
            in (json['progress'] as List<dynamic>?) ?? <dynamic>[])
          _pointFromJson(asJsonMap(p)),
      ],
      distribution: <HistogramBucket>[
        for (final dynamic b
            in (json['distribution'] as List<dynamic>?) ?? <dynamic>[])
          _bucketFromJson(asJsonMap(b)),
      ],
    );
  }

  static StatsPoint _pointFromJson(Map<String, dynamic> json) => StatsPoint(
        day: DateTime.parse(json['day'] as String).toLocal(),
        bestMs: _int(json['best_ms']) ?? 0,
        averageMs: _int(json['average_ms']) ?? 0,
        solveCount: _int(json['solve_count']) ?? 0,
      );

  static HistogramBucket _bucketFromJson(Map<String, dynamic> json) =>
      HistogramBucket(
        fromMs: _int(json['from_ms']) ?? 0,
        toMs: _int(json['to_ms']) ?? 0,
        count: _int(json['count']) ?? 0,
      );

  static LeaderboardEntry _entryFromJson(
    Map<String, dynamic> json, {
    bool isCurrentUser = false,
  }) =>
      LeaderboardEntry(
        userId: json['user_id'] as String? ?? '',
        rank: _int(json['rank']) ?? 0,
        displayName: json['display_name'] as String? ?? 'Unknown',
        timeMs: _int(json['time_ms']) ?? 0,
        countryCode: json['country'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        isCurrentUser: isCurrentUser || (json['is_me'] as bool? ?? false),
      );

  static PlayerProfile _profileFromJson(Map<String, dynamic> json) {
    final dynamic h2h = json['head_to_head'];

    return PlayerProfile(
      userId: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Unknown',
      countryCode: json['country'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      elo: _int(json['elo']),
      bestSingleMs: _int(json['best_single_ms']),
      bestAo5Ms: _int(json['best_ao5_ms']),
      bestAo12Ms: _int(json['best_ao12_ms']),
      headToHead: h2h is Map
          ? HeadToHead(
              wins: _int(asJsonMap(h2h)['wins']) ?? 0,
              losses: _int(asJsonMap(h2h)['losses']) ?? 0,
            )
          : null,
    );
  }

  static int? _int(dynamic value) => value is num ? value.toInt() : null;
}
