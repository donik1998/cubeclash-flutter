import 'package:dio/dio.dart';

import '../../../../core/error/result.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_failures.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/player_stats.dart';
import '../../domain/repositories/stats_repository.dart';
import '../models/leaderboard_dto.dart';

/// The real [StatsRepository].
///
/// Verified against the live server (real captured bytes, July 2026). Two notes
/// worth being honest about:
///
///  * `GET /stats` returns `{event, best_single_ms, ao5, ao12, ao100,
///    session_average, pb_count, solve_count}` — the average keys are `ao5` /
///    `ao12` / `ao100`, **not** the `best_ao*_ms` this client first proposed.
///    Those are the current rolling averages (the server does not yet expose a
///    best-of-window figure); we surface them in the "Best Ao5" cards as the
///    closest available value. The server does **not** return `progress` or
///    `distribution` arrays, so the charts have no data yet — parsed leniently
///    (absent → empty) rather than crashing; a real backend gap to close.
///  * `GET /leaderboard` matches the client row shape exactly (`items` /
///    `next_cursor` / `viewer`, ranking value as `value_ms`).
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

          // DTO (total wire mirror) → mapper (drop rules) → domain model. An
          // unknown event never reaches here — the server returns the standard
          // error envelope (`unknown_event`) and `dioFailure` maps the non-2xx
          // to a Failure before we ever parse a body.
          final LeaderboardResponseDto dto = LeaderboardResponseDto.fromJson(
            asJsonMap(response.data),
          );
          return LeaderboardMapper.responseToDomain(dto);
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
      // The live server names the averages `ao5`/`ao12`/`ao100` (verified
      // against real bytes, July 2026). The proposed `best_ao*_ms` names never
      // materialised, so read the wire names first and keep the old ones as a
      // fallback in case the server ever grows the best-of variants.
      bestAo5Ms: _int(json['ao5']) ?? _int(json['best_ao5_ms']),
      bestAo12Ms: _int(json['ao12']) ?? _int(json['best_ao12_ms']),
      bestAo100Ms: _int(json['ao100']) ?? _int(json['best_ao100_ms']),
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
