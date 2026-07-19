import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/error/result.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_failures.dart';
import '../../../../core/network/page.dart';
import '../../domain/entities/penalty.dart';
import '../../domain/entities/solve.dart';
import '../../domain/repositories/solve_repository.dart';
import '../models/solve_dto.dart';

/// The real [SolveRepository], talking to `cubeclash-backend` over REST.
///
/// Written against the documented contract (docs → API Design § Solves) even
/// though nothing answers yet — the endpoints, field names and status codes are
/// the spec, so this compiles and is reviewable today and becomes live the
/// moment the server exists. Swap it in with `--dart-define=USE_FAKE_DATA=false`.
///
/// **Session handling is in-memory for now.** CLAUDE.md calls for a local-first
/// Drift store, but full offline sync is explicitly fast-follow rather than MVP
/// (docs → Concept & Scope: "MVP keeps local persistence + online PvP"). The
/// session mirror below is the seam that store will slot into: [watchSession]
/// already streams, so nothing above this layer changes when it lands.
class SolveRepositoryImpl implements SolveRepository {
  SolveRepositoryImpl(this._client);

  final DioClient _client;

  final List<Solve> _session = <Solve>[];
  final StreamController<List<Solve>> _sessionController =
      StreamController<List<Solve>>.broadcast();

  @override
  Stream<List<Solve>> watchSession() async* {
    yield List<Solve>.unmodifiable(_session);
    yield* _sessionController.stream;
  }

  void _emitSession() =>
      _sessionController.add(List<Solve>.unmodifiable(_session));

  @override
  Future<Result<Solve>> addSolve({
    required String event,
    required String scramble,
    required int timeMs,
    required Penalty penalty,
    required DateTime solvedAt,
    required String clientId,
  }) =>
      Result.guard<Solve>(
        () async {
          final Response<dynamic> response = await _client.dio.post<dynamic>(
            '/solves',
            data: SolveDto.toCreateJson(
              event: event,
              scramble: scramble,
              timeMs: timeMs,
              penalty: penalty,
              solvedAt: solvedAt,
              clientId: clientId,
            ),
          );
          final Solve solve = SolveDto.fromJson(
            unwrap(response.data, 'solve'),
          );
          _session.add(solve);
          _emitSession();
          return solve;
        },
        onError: dioFailure,
      );

  @override
  Future<Result<Solve>> updatePenalty(String id, Penalty penalty) =>
      Result.guard<Solve>(
        () async {
          final Response<dynamic> response = await _client.dio.patch<dynamic>(
            '/solves/$id',
            data: <String, dynamic>{
              'penalty': SolveDto.penaltyToWire(penalty),
            },
          );
          final Solve solve = SolveDto.fromJson(
            unwrap(response.data, 'solve'),
          );

          final int index = _session.indexWhere((Solve s) => s.id == id);
          if (index != -1) {
            _session[index] = solve;
            _emitSession();
          }
          return solve;
        },
        onError: dioFailure,
      );

  @override
  Future<Result<void>> deleteSolve(String id) => Result.guard<void>(
        () async {
          await _client.dio.delete<dynamic>('/solves/$id');
          _session.removeWhere((Solve s) => s.id == id);
          _emitSession();
        },
        onError: dioFailure,
      );

  @override
  Future<Result<Page<Solve>>> getHistory({
    String event = '3x3',
    String? cursor,
  }) =>
      Result.guard<Page<Solve>>(
        () async {
          final Response<dynamic> response = await _client.dio.get<dynamic>(
            '/solves',
            queryParameters: <String, dynamic>{
              'event': event,
              if (cursor != null) 'cursor': cursor,
            },
          );
          final Map<String, dynamic> body = asJsonMap(response.data);
          final List<dynamic> items =
              (body['items'] as List<dynamic>?) ?? <dynamic>[];

          return Page<Solve>(
            items: items
                .map((dynamic e) =>
                    SolveDto.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(),
            nextCursor: body['next_cursor'] as String?,
          );
        },
        onError: dioFailure,
      );

  @override
  Future<Result<void>> clearSession() async {
    // Purely client-side — there is no `sessions` table (docs → Data Model),
    // so ending a session touches no endpoint and deletes nothing.
    _session.clear();
    _emitSession();
    return const Ok<void>(null);
  }

  Future<void> dispose() => _sessionController.close();
}
