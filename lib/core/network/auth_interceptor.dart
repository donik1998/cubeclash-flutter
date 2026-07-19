import 'package:dio/dio.dart';

/// In-memory token store. Swap for secure storage (e.g. flutter_secure_storage)
/// when the auth feature lands. Access + refresh with rotation per docs/API Design.
class TokenStore {
  String? accessToken;
  String? refreshToken;

  bool get hasSession => accessToken != null;

  void setTokens({required String access, required String refresh}) {
    accessToken = access;
    refreshToken = refresh;
  }

  void clear() {
    accessToken = null;
    refreshToken = null;
  }
}

/// Attaches the JWT to every request and (later) transparently refreshes on 401.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokens);

  final TokenStore _tokens;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final String? token = _tokens.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // TODO(auth): on 401, POST /auth/refresh with the refresh token, then retry
    // the original request once. No-op stub for now so the scaffold builds
    // without a running backend.
    handler.next(err);
  }
}
