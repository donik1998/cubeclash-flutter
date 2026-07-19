import 'dart:convert';
import 'dart:typed_data';

import 'package:cubeclash/core/network/auth_interceptor.dart';
import 'package:cubeclash/core/network/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A hand-rolled [HttpClientAdapter] so the interceptor is tested against a
/// real Dio pipeline rather than a mock of it.
///
/// The refresh flow is the one piece of this app that only misbehaves under
/// concurrency and only on a code path users hit constantly (a ~15-minute
/// access token expires mid-session by design). It is worth testing properly.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handler);

  /// Called for every request; returns the response to serve.
  final ResponseBody Function(RequestOptions options) handler;

  /// Every path requested, in order.
  final List<String> requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.path);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body, int status) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

void main() {
  late InMemoryTokenStorage storage;
  late TokenStore tokens;

  setUp(() async {
    storage = InMemoryTokenStorage();
    tokens = TokenStore(storage);
    await tokens.restore();
    await tokens.setTokens(access: 'old-access', refresh: 'old-refresh');
  });

  /// Builds a Dio pair wired exactly as [DioClient] does.
  ({Dio client, _ScriptedAdapter adapter}) buildClient(
    ResponseBody Function(RequestOptions) handler,
  ) {
    final _ScriptedAdapter adapter = _ScriptedAdapter(handler);

    final Dio refreshClient = Dio(BaseOptions(baseUrl: 'https://api.test/v1'))
      ..httpClientAdapter = adapter;
    final Dio client = Dio(BaseOptions(baseUrl: 'https://api.test/v1'))
      ..httpClientAdapter = adapter
      ..interceptors.add(AuthInterceptor(tokens, refreshClient));

    return (client: client, adapter: adapter);
  }

  test('attaches the access token to every request', () async {
    String? seenAuth;
    final ({_ScriptedAdapter adapter, Dio client}) setup = buildClient((
      RequestOptions options,
    ) {
      seenAuth = options.headers['Authorization'] as String?;
      return _json(<String, dynamic>{'ok': 1}, 200);
    });

    await setup.client.get<dynamic>('/me');
    expect(seenAuth, 'Bearer old-access');
  });

  test('refreshes on a 401 and retries the original request once', () async {
    bool refreshed = false;
    final List<String?> authHeaders = <String?>[];

    final ({_ScriptedAdapter adapter, Dio client}) setup = buildClient((
      RequestOptions options,
    ) {
      if (options.path.contains('/auth/refresh')) {
        refreshed = true;
        return _json(<String, dynamic>{
          'tokens': <String, dynamic>{
            'access': 'new-access',
            'refresh': 'new-refresh',
          },
        }, 200);
      }

      authHeaders.add(options.headers['Authorization'] as String?);
      // First attempt fails; the retry (with the new token) succeeds.
      return authHeaders.length == 1
          ? _json(<String, dynamic>{'error': 1}, 401)
          : _json(<String, dynamic>{'ok': 1}, 200);
    });

    final Response<dynamic> response = await setup.client.get<dynamic>('/me');

    expect(response.statusCode, 200);
    expect(refreshed, isTrue);
    expect(authHeaders, <String>['Bearer old-access', 'Bearer new-access']);
    // Rotation: both tokens are replaced, and the old refresh token is gone.
    expect(tokens.accessToken, 'new-access');
    expect(tokens.refreshToken, 'new-refresh');
  });

  test('a failed refresh clears the session so the router can redirect',
      () async {
    int notifications = 0;
    tokens.addListener(() => notifications++);

    final ({_ScriptedAdapter adapter, Dio client}) setup = buildClient((
      RequestOptions options,
    ) =>
        _json(<String, dynamic>{'error': 1}, 401));

    await expectLater(
      setup.client.get<dynamic>('/me'),
      throwsA(isA<DioException>()),
    );

    expect(tokens.hasSession, isFalse);
    expect(notifications, greaterThanOrEqualTo(1));
  });

  test('does not loop: a retry that also 401s is not refreshed again',
      () async {
    int refreshCalls = 0;

    final ({_ScriptedAdapter adapter, Dio client}) setup = buildClient((
      RequestOptions options,
    ) {
      if (options.path.contains('/auth/refresh')) {
        refreshCalls++;
        return _json(<String, dynamic>{
          'tokens': <String, dynamic>{
            'access': 'new-access',
            'refresh': 'new-refresh',
          },
        }, 200);
      }
      // The server rejects even the freshly refreshed token.
      return _json(<String, dynamic>{'error': 1}, 401);
    });

    await expectLater(
      setup.client.get<dynamic>('/me'),
      throwsA(isA<DioException>()),
    );

    expect(
      refreshCalls,
      1,
      reason: 'a dead session must fail, not spin on refresh',
    );
  });

  test('concurrent 401s share one refresh', () async {
    int refreshCalls = 0;
    final Set<String> seenTokens = <String>{};

    final ({_ScriptedAdapter adapter, Dio client}) setup = buildClient((
      RequestOptions options,
    ) {
      if (options.path.contains('/auth/refresh')) {
        refreshCalls++;
        return _json(<String, dynamic>{
          'tokens': <String, dynamic>{
            'access': 'new-access',
            'refresh': 'new-refresh',
          },
        }, 200);
      }

      final String auth = options.headers['Authorization'] as String;
      seenTokens.add(auth);
      return auth == 'Bearer old-access'
          ? _json(<String, dynamic>{'error': 1}, 401)
          : _json(<String, dynamic>{'ok': 1}, 200);
    });

    // Three requests in flight, all with a stale token.
    final List<Response<dynamic>> responses =
        await Future.wait<Response<dynamic>>(
      <Future<Response<dynamic>>>[
        setup.client.get<dynamic>('/me'),
        setup.client.get<dynamic>('/solves'),
        setup.client.get<dynamic>('/stats'),
      ],
    );

    expect(
        responses.every((Response<dynamic> r) => r.statusCode == 200), isTrue);
    expect(
      refreshCalls,
      1,
      reason: 'rotation means a second refresh would present a dead token '
          'and log the user out during a recoverable blip',
    );
  });

  test('a non-401 error passes straight through', () async {
    int refreshCalls = 0;

    final ({_ScriptedAdapter adapter, Dio client}) setup = buildClient((
      RequestOptions options,
    ) {
      if (options.path.contains('/auth/refresh')) refreshCalls++;
      return _json(<String, dynamic>{'error': 1}, 500);
    });

    await expectLater(
      setup.client.get<dynamic>('/me'),
      throwsA(isA<DioException>()),
    );

    expect(refreshCalls, 0);
    expect(tokens.hasSession, isTrue, reason: 'a 500 is not a dead session');
  });

  test('with no refresh token there is nothing to refresh', () async {
    await tokens.clear();

    int refreshCalls = 0;
    final ({_ScriptedAdapter adapter, Dio client}) setup = buildClient((
      RequestOptions options,
    ) {
      if (options.path.contains('/auth/refresh')) refreshCalls++;
      return _json(<String, dynamic>{'error': 1}, 401);
    });

    await expectLater(
      setup.client.get<dynamic>('/me'),
      throwsA(isA<DioException>()),
    );

    expect(refreshCalls, 0);
  });
}
