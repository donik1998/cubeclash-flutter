import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/dio_client.dart';
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
            _unwrap(response.data, 'solve'),
          );
          _session.add(solve);
          _emitSession();
          return solve;
        },
        onError: _toFailure,
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
            _unwrap(response.data, 'solve'),
          );

          final int index = _session.indexWhere((Solve s) => s.id == id);
          if (index != -1) {
            _session[index] = solve;
            _emitSession();
          }
          return solve;
        },
        onError: _toFailure,
      );

  @override
  Future<Result<void>> deleteSolve(String id) => Result.guard<void>(
        () async {
          await _client.dio.delete<dynamic>('/solves/$id');
          _session.removeWhere((Solve s) => s.id == id);
          _emitSession();
        },
        onError: _toFailure,
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
          final Map<String, dynamic> body = _asMap(response.data);
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
        onError: _toFailure,
      );

  @override
  Future<Result<void>> clearSession() async {
    // Purely client-side — there is no `sessions` table (docs → Data Model),
    // so ending a session touches no endpoint and deletes nothing.
    _session.clear();
    _emitSession();
    return const Ok<void>(null);
  }

  /// Responses are documented as wrapping their payload (`{ solve }`,
  /// `{ user }`). Tolerate a bare object too, so a server that returns the
  /// resource unwrapped doesn't break the client.
  Map<String, dynamic> _unwrap(dynamic data, String key) {
    final Map<String, dynamic> body = _asMap(data);
    final dynamic inner = body[key];
    return inner is Map ? Map<String, dynamic>.from(inner) : body;
  }

  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  /// Maps transport errors onto domain failures, including the server's
  /// documented error envelope `{ error: { code, message, details } }`.
  static Failure _toFailure(Object error, StackTrace _) {
    if (error is! DioException) {
      return ServerFailure('Unexpected error: $error');
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure(
          "Can't reach CubeClash. Check your connection.",
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return const NetworkFailure('The request could not be completed.');
      case DioExceptionType.badResponse:
        break;
    }

    final int? status = error.response?.statusCode;

    // Documented envelope: `{ error: { code, message, details } }`.
    String? serverMessage;
    final dynamic data = error.response?.data;
    if (data is Map) {
      final dynamic envelope = data['error'];
      if (envelope is Map) {
        final dynamic message = envelope['message'];
        if (message is String) serverMessage = message;
      }
    }

    if (status == 401 || status == 403) {
      return AuthFailure(serverMessage ?? 'Please sign in again.');
    }
    return ServerFailure(serverMessage ?? 'The server rejected that request.');
  }

  Future<void> dispose() => _sessionController.close();
}
