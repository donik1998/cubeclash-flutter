import 'package:dio/dio.dart';

import '../error/failures.dart';

/// Maps a transport error onto a domain [Failure].
///
/// Shared by every repository implementation so error handling is consistent —
/// a timeout reads the same whether it happened fetching solves or a
/// leaderboard, and the server's documented envelope
/// `{ error: { code, message, details } }` is unwrapped in exactly one place.
///
/// Pass to `Result.guard(..., onError: dioFailure)`.
Failure dioFailure(Object error, StackTrace _) {
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
  final String? serverMessage = _messageFrom(error.response?.data);

  // 401/403 are distinct because the router's auth guard reacts to AuthFailure.
  if (status == 401 || status == 403) {
    return AuthFailure(serverMessage ?? 'Please sign in again.');
  }
  if (status == 404) {
    return ServerFailure(serverMessage ?? "That doesn't exist.");
  }
  if (status == 429) {
    return ServerFailure(
      serverMessage ?? 'Too many requests — give it a moment.',
    );
  }
  return ServerFailure(serverMessage ?? 'The server rejected that request.');
}

String? _messageFrom(dynamic data) {
  if (data is! Map) return null;
  final dynamic envelope = data['error'];
  if (envelope is! Map) return null;
  final dynamic message = envelope['message'];
  return message is String ? message : null;
}

/// Responses are documented as wrapping their payload (`{ solve }`, `{ user }`).
/// Tolerates a bare object too, so a server that returns the resource unwrapped
/// does not break the client.
Map<String, dynamic> unwrap(dynamic data, String key) {
  final Map<String, dynamic> body = asJsonMap(data);
  final dynamic inner = body[key];
  return inner is Map ? Map<String, dynamic>.from(inner) : body;
}

Map<String, dynamic> asJsonMap(dynamic data) =>
    data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
