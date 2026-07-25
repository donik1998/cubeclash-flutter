import 'package:dio/dio.dart';

import '../../../../core/error/result.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_failures.dart';
import '../../domain/entities/lobby_summary.dart';
import '../../domain/repositories/race_lobby_repository.dart';

/// The real [RaceLobbyRepository].
class RaceLobbyRepositoryImpl implements RaceLobbyRepository {
  RaceLobbyRepositoryImpl(this._client);

  final DioClient _client;

  @override
  Future<Result<LobbySummary>> summary() => Result.guard<LobbySummary>(
        () async {
          final Response<dynamic> response =
              await _client.dio.get<dynamic>('/race/summary');
          final Map<String, dynamic> json = asJsonMap(response.data);
          return LobbySummary(
            elo: _int(json['elo']) ?? 0,
            globalRank: _int(json['global_rank']) ?? 0,
            wins: _int(json['wins']) ?? 0,
            losses: _int(json['losses']) ?? 0,
            bestSingleMs: _int(json['best_single_ms']),
            ao5Ms: _int(json['ao5_ms']),
            recentRivals: <Rival>[
              for (final dynamic r
                  in (json['recent_rivals'] as List<dynamic>?) ?? <dynamic>[])
                _rivalFromJson(asJsonMap(r)),
            ],
          );
        },
        onError: dioFailure,
      );

  static Rival _rivalFromJson(Map<String, dynamic> json) => Rival(
        userId: json['user_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        wins: _int(json['wins']) ?? 0,
        losses: _int(json['losses']) ?? 0,
        countryCode: json['country'] as String?,
      );

  static int? _int(dynamic v) => v is num ? v.toInt() : null;
}
