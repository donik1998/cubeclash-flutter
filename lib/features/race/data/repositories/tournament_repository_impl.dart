import 'package:dio/dio.dart';

import '../../../../core/error/result.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_failures.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/repositories/tournament_repository.dart';

/// The real [TournamentRepository], against the proposed tournament endpoints.
class TournamentRepositoryImpl implements TournamentRepository {
  TournamentRepositoryImpl(this._client);

  final DioClient _client;

  @override
  Future<Result<List<Tournament>>> getTournaments() =>
      Result.guard<List<Tournament>>(
        () async {
          final Response<dynamic> response =
              await _client.dio.get<dynamic>('/tournaments');
          final Map<String, dynamic> body = asJsonMap(response.data);
          final List<dynamic> items =
              (body['items'] as List<dynamic>?) ?? <dynamic>[];
          return <Tournament>[
            for (final dynamic t in items) _fromJson(asJsonMap(t)),
          ];
        },
        onError: dioFailure,
      );

  @override
  Future<Result<TournamentDetail>> getTournament(String id) =>
      Result.guard<TournamentDetail>(
        () async {
          final Response<dynamic> response =
              await _client.dio.get<dynamic>('/tournaments/$id');
          final Map<String, dynamic> body = asJsonMap(response.data);
          final Map<String, dynamic> t = asJsonMap(body['tournament']);
          final List<dynamic> rounds =
              (body['rounds'] as List<dynamic>?) ?? <dynamic>[];
          return TournamentDetail(
            tournament: _fromJson(t),
            rounds: <TournamentRound>[
              for (final dynamic r in rounds) _roundFromJson(asJsonMap(r)),
            ],
          );
        },
        onError: dioFailure,
      );

  @override
  Future<Result<void>> register(String id) => Result.guard<void>(
        () => _client.dio.post<dynamic>('/tournaments/$id/register'),
        onError: dioFailure,
      );

  static Tournament _fromJson(Map<String, dynamic> json) => Tournament(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        event: json['event'] as String? ?? '3x3',
        status: _status(json['status'] as String?),
        entrants: _int(json['entrants']) ?? 0,
        capacity: _int(json['capacity']) ?? 0,
        startsAt: DateTime.tryParse(json['starts_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        description: json['description'] as String? ?? '',
        registered: json['registered'] as bool? ?? false,
      );

  static TournamentRound _roundFromJson(Map<String, dynamic> json) =>
      TournamentRound(
        name: json['name'] as String? ?? '',
        matches: <TournamentMatch>[
          for (final dynamic m
              in (json['matches'] as List<dynamic>?) ?? <dynamic>[])
            _matchFromJson(asJsonMap(m)),
        ],
      );

  static TournamentMatch _matchFromJson(Map<String, dynamic> json) =>
      TournamentMatch(
        playerA: json['player_a'] as String? ?? '',
        playerB: json['player_b'] as String? ?? '',
        timeAMs: _int(json['time_a_ms']),
        timeBMs: _int(json['time_b_ms']),
        winner: json['winner'] as String?,
      );

  static TournamentStatus _status(String? wire) => switch (wire) {
        'live' => TournamentStatus.live,
        'finished' => TournamentStatus.finished,
        _ => TournamentStatus.upcoming,
      };

  static int? _int(dynamic v) => v is num ? v.toInt() : null;
}
