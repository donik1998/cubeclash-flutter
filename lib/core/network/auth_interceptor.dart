import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'token_storage.dart';

/// Holds the session, in memory and on disk.
///
/// In-memory as well as persisted because the interceptor needs the access
/// token synchronously on every request — awaiting the Keychain per call would
/// put a platform round trip in front of all traffic. Disk is written through
/// on change and read once at bootstrap.
///
/// A [ChangeNotifier] so go_router can rebuild its redirect when the session
/// appears or disappears (see `AppRouter.refreshListenable`).
class TokenStore extends ChangeNotifier {
  TokenStore(this._storage);

  final TokenStorage _storage;

  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  bool get hasSession => _accessToken != null;

  /// True until [restore] has run. The router shows a splash rather than
  /// bouncing a signed-in user to the auth stack for one frame.
  bool _restored = false;
  bool get isRestored => _restored;

  /// Loads a persisted session. Called during bootstrap.
  Future<void> restore() async {
    final TokenPair? tokens = await _storage.read();
    _accessToken = tokens?.access;
    _refreshToken = tokens?.refresh;
    _restored = true;
    notifyListeners();
  }

  Future<void> setTokens({
    required String access,
    required String refresh,
  }) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _storage.write(TokenPair(access: access, refresh: refresh));
    notifyListeners();
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.clear();
    notifyListeners();
  }
}

/// Attaches the JWT and transparently refreshes it on a 401.
///
/// Access tokens are short (~15 min, docs → API Design), so expiry mid-session
/// is the normal case, not an edge case. The flow:
///
///   1. 401 arrives.
///   2. `POST /auth/refresh` with the refresh token (rotation: the response
///      carries a new refresh token too, and the old one is now dead).
///   3. Retry the original request **once** with the new access token.
///   4. If the refresh fails, clear the session — the router's guard sees the
///      notification and redirects to the auth stack.
///
/// Two details that matter:
///
///  * **Single-flight.** A screen that fires three requests at once gets three
///    401s. Without a shared future they would each refresh, and rotation
///    means the second and third would present an already-rotated token and
///    fail — logging the user out during a perfectly recoverable blip. They
///    all await the same refresh instead.
///  * **No retry loop.** The retry is marked so its own 401 cannot trigger
///    another refresh. A refresh that yields a token the server still rejects
///    is a dead session, not something to spin on.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokens, this._refreshClient);

  final TokenStore _tokens;

  /// A **separate** Dio without this interceptor. Refreshing through the
  /// intercepted client would recurse on its own 401.
  final Dio _refreshClient;

  static const String _retriedFlag = 'cubeclash.retried_after_refresh';

  /// In flight refresh, shared by every request that 401s while it runs.
  Future<bool>? _refreshInFlight;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final String? token = _tokens.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions request = err.requestOptions;

    final bool isAuthFailure = err.response?.statusCode == 401;
    final bool alreadyRetried = request.extra[_retriedFlag] == true;
    final bool isRefreshCall = request.path.contains('/auth/refresh');

    if (!isAuthFailure ||
        alreadyRetried ||
        isRefreshCall ||
        _tokens.refreshToken == null) {
      return handler.next(err);
    }

    final bool refreshed = await _refresh();
    if (!refreshed) {
      // Session is dead. Clearing notifies the router, which redirects.
      await _tokens.clear();
      return handler.next(err);
    }

    try {
      final Response<dynamic> response = await _refreshClient.fetch<dynamic>(
        request
          ..headers['Authorization'] = 'Bearer ${_tokens.accessToken}'
          ..extra[_retriedFlag] = true,
      );
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  /// Runs at most one refresh at a time; concurrent callers share the result.
  Future<bool> _refresh() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    try {
      final Response<dynamic> response = await _refreshClient.post<dynamic>(
        '${ApiConfig.apiBase}/auth/refresh',
        data: <String, dynamic>{'refresh': _tokens.refreshToken},
      );

      final dynamic body = response.data;
      final dynamic tokens = body is Map ? body['tokens'] : null;
      if (tokens is! Map) return false;

      final String? access = tokens['access'] as String?;
      // Rotation: a refresh returns a new refresh token and invalidates the
      // old one. Falling back to the current one would leave a dead token in
      // storage.
      final String? refresh =
          tokens['refresh'] as String? ?? _tokens.refreshToken;
      if (access == null || refresh == null) return false;

      await _tokens.setTokens(access: access, refresh: refresh);
      return true;
    } on DioException {
      return false;
    }
  }
}
