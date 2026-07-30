import 'package:dio/dio.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_failures.dart';
import '../../domain/repositories/auth_repository.dart';

/// The real [AuthRepository].
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client, this._tokens);

  final DioClient _client;
  final TokenStore _tokens;

  @override
  bool get hasSession => _tokens.hasSession;

  @override
  Future<Result<void>> register({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _authCall(
        '/auth/register',
        <String, dynamic>{
          'email': email.trim(),
          'password': password,
          'display_name': displayName.trim(),
        },
      );

  @override
  Future<Result<void>> login({
    required String email,
    required String password,
  }) =>
      _authCall(
        '/auth/login',
        <String, dynamic>{'email': email.trim(), 'password': password},
      );

  @override
  Future<Result<void>> completeProfile({
    required String displayName,
    String? country,
  }) =>
      Result.guard<void>(
        () => _client.dio.patch<dynamic>(
          '/me',
          data: <String, dynamic>{
            'display_name': displayName.trim(),
            if (country != null) 'country': country,
          },
        ),
        onError: dioFailure,
      );

  @override
  Future<Result<void>> logout() async {
    // The live server revokes by refresh token, not access token: `POST
    // /auth/logout` requires `{ refresh }` in the body (a bare call 400s with
    // "refresh should not be empty"). Capture it before the local clear below.
    final String? refresh = _tokens.refreshToken;
    final Result<void> result = await Result.guard<void>(
      () => _client.dio.post<dynamic>(
        '/auth/logout',
        data: <String, dynamic>{if (refresh != null) 'refresh': refresh},
      ),
      onError: dioFailure,
    );
    // Local clear happens whatever the server said — see ProfileRepositoryImpl
    // for the same reasoning.
    await _tokens.clear();
    return result;
  }

  /// Register and login are the same shape: post credentials, store the
  /// returned pair.
  Future<Result<void>> _authCall(String path, Map<String, dynamic> body) =>
      Result.guard<void>(
        () async {
          final Response<dynamic> response =
              await _client.dio.post<dynamic>(path, data: body);

          final Map<String, dynamic> tokens = unwrap(response.data, 'tokens');
          final String? access = tokens['access'] as String?;
          final String? refresh = tokens['refresh'] as String?;

          if (access == null || refresh == null) {
            // A 200 with no usable tokens is a broken contract, not a
            // successful sign-in — fail loudly rather than land the user in a
            // shell they'll be bounced out of on the first request.
            throw DioException(
              requestOptions: response.requestOptions,
              response: response,
              message: 'Sign-in response carried no tokens.',
            );
          }

          await _tokens.setTokens(access: access, refresh: refresh);
        },
        onError: (Object error, StackTrace stack) {
          final Failure failure = dioFailure(error, stack);
          // 401 on a *login* means bad credentials, not an expired session —
          // the generic "please sign in again" would be nonsense here.
          if (error is DioException && error.response?.statusCode == 401) {
            return const AuthFailure('That email or password is incorrect.');
          }
          return failure;
        },
      );
}
