import 'package:cubeclash/core/error/result.dart';
import 'package:cubeclash/core/network/api_config.dart';
import 'package:cubeclash/core/network/auth_interceptor.dart';
import 'package:cubeclash/core/network/dio_client.dart';
import 'package:cubeclash/core/network/page.dart';
import 'package:cubeclash/core/network/token_storage.dart';
import 'package:cubeclash/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:cubeclash/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:cubeclash/features/profile/data/repositories/profile_summary_repository_impl.dart';
import 'package:cubeclash/features/profile/domain/entities/profile_summary.dart';
import 'package:cubeclash/features/profile/domain/entities/user_profile.dart';
import 'package:cubeclash/features/stats/domain/entities/leaderboard_entry.dart';
import 'package:cubeclash/features/stats/data/repositories/stats_repository_impl.dart';
import 'package:cubeclash/features/stats/domain/entities/player_stats.dart';
import 'package:cubeclash/features/timer/data/repositories/solve_repository_impl.dart';
import 'package:cubeclash/features/timer/domain/entities/penalty.dart';
import 'package:cubeclash/features/timer/domain/entities/solve.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end tests against a **running `cubeclash-backend`**.
///
/// Skipped by default so CI stays green with no server. To run them:
///
/// ```sh
/// # backend listening on http://localhost:3100 (client appends /v1)
/// flutter test test/integration/live_api_test.dart \
///     --dart-define=LIVE_API=true
///
/// # against another host:
/// flutter test test/integration/live_api_test.dart \
///     --dart-define=LIVE_API=true \
///     --dart-define=API_BASE_URL=http://localhost:3100
/// ```
///
/// Each run registers a fresh throwaway user, so it is idempotent and leaves no
/// shared state behind (beyond that user row).
const bool kLive = bool.fromEnvironment('LIVE_API');

void main() {
  group('live API', _liveTests,
      skip: kLive
          ? false
          : 'live suite — run with --dart-define=LIVE_API=true against a '
              'running backend (see file header)');
}

void _liveTests() {
  // A brand-new client + token store per test, wired exactly like DioClient in
  // production. InMemoryTokenStorage avoids the secure-storage platform channel
  // that never answers under `flutter test`.
  late TokenStore tokens;
  late DioClient client;
  late AuthRepositoryImpl auth;
  late ProfileRepositoryImpl profile;
  late ProfileSummaryRepositoryImpl summary;
  late StatsRepositoryImpl stats;
  late SolveRepositoryImpl solves;

  String uniqueEmail() =>
      'wire_${DateTime.now().microsecondsSinceEpoch}@ex.com';

  Future<void> registerFresh() async {
    final Result<void> r = await auth.register(
      email: uniqueEmail(),
      password: 'hunter2hunter2',
      displayName: 'wiretest',
    );
    expect(r, isA<Ok<void>>(), reason: 'registration should succeed');
    expect(tokens.hasSession, isTrue);
  }

  setUp(() async {
    tokens = TokenStore(InMemoryTokenStorage());
    await tokens.restore();
    client = DioClient(tokens);
    auth = AuthRepositoryImpl(client, tokens);
    profile = ProfileRepositoryImpl(client, tokens);
    summary = ProfileSummaryRepositoryImpl(client);
    stats = StatsRepositoryImpl(client);
    solves = SolveRepositoryImpl(client);
  });

  test('base URL points at the configured server', () {
    // Sanity: a misconfigured base is the most common reason the suite "passes"
    // by never actually reaching a server.
    expect(ApiConfig.apiBase, endsWith('/v1'));
  });

  test('register → me round-trips a real user', () async {
    await registerFresh();
    final Result<UserProfile> me = await profile.getMe();
    final UserProfile user = (me as Ok<UserProfile>).value;
    expect(user.id, isNotEmpty);
    expect(user.email, contains('@'));
    expect(user.elo, 1000);
  });

  test('a solve round-trips: create → history', () async {
    await registerFresh();
    final Result<Solve> created = await solves.addSolve(
      event: '3x3',
      scramble: "R U R' U' F2 L D2 B'",
      timeMs: 8137,
      penalty: Penalty.none,
      solvedAt: DateTime.now().toUtc(),
      clientId: 'wire-s1',
    );
    final Solve solve = (created as Ok<Solve>).value;
    expect(solve.id, isNotEmpty);

    final Result<Page<Solve>> history = await solves.getHistory();
    final Page<Solve> page = (history as Ok<Page<Solve>>).value;
    expect(page.items.map((Solve s) => s.id), contains(solve.id));
  });

  test('idempotent create: same client_id does not duplicate', () async {
    await registerFresh();
    Future<Result<Solve>> post() => solves.addSolve(
          event: '3x3',
          scramble: "R U R' U' F2 L D2 B'",
          timeMs: 7500,
          penalty: Penalty.none,
          solvedAt: DateTime.now().toUtc(),
          clientId: 'wire-dup',
        );
    final Solve a = (await post() as Ok<Solve>).value;
    final Solve b = (await post() as Ok<Solve>).value;
    expect(a.id, b.id, reason: 'upsert on (user_id, client_id)');
  });

  test('stats returns the ao5/ao12 shape (empty for a fresh user)', () async {
    await registerFresh();
    final Result<PlayerStats> r = await stats.getStats();
    final PlayerStats s = (r as Ok<PlayerStats>).value;
    expect(s.event, '3x3');
    expect(s.solveCount, 0);
    expect(s.bestSingleMs, isNull);
  });

  test('leaderboard requires a JWT and returns the seeded board', () async {
    await registerFresh();
    final Result<Leaderboard> r = await stats.getLeaderboard();
    final Leaderboard board = (r as Ok<Leaderboard>).value;
    expect(board.entries, isNotEmpty, reason: 'seeded users are on the board');
    expect(board.entries.first.timeMs, greaterThan(0));
  });

  test('me/profile requires a JWT and returns the composite', () async {
    await registerFresh();
    final Result<ProfileSummary> r = await summary.getProfileSummary();
    final ProfileSummary s = (r as Ok<ProfileSummary>).value;
    expect(s.id, isNotEmpty);
    expect(s.elo, 1000);
  });

  test('leaderboard WITHOUT a JWT is rejected (the breaking change)', () async {
    // No session at all → the interceptor attaches no Bearer, and with no
    // refresh token it cannot recover. The old X-User-Id path is gone.
    final Result<Leaderboard> r = await stats.getLeaderboard();
    expect(r, isA<Err<Leaderboard>>(),
        reason: 'GET /leaderboard now requires Authorization: Bearer');
  });

  test(
      'AuthInterceptor refreshes a rejected access token against the real '
      'refresh endpoint', () async {
    await registerFresh();
    final String realRefresh = tokens.refreshToken!;
    // Poison the access token but keep the real refresh: the next call 401s,
    // the interceptor refreshes for real, retries, and succeeds.
    await tokens.setTokens(access: 'not.a.valid.jwt', refresh: realRefresh);

    final Result<UserProfile> me = await profile.getMe();
    expect(me, isA<Ok<UserProfile>>(),
        reason: 'the interceptor recovered the session transparently');
    expect(tokens.accessToken, isNot('not.a.valid.jwt'));
    expect(tokens.refreshToken, isNot(realRefresh),
        reason: 'rotation replaced the refresh token');
  });

  test('refresh rotation is single-use: a replayed token is revoked', () async {
    await registerFresh();
    final String spent = tokens.refreshToken!;

    // First use rotates successfully (drive it through the interceptor by
    // poisoning the access token as above).
    await tokens.setTokens(access: 'garbage', refresh: spent);
    final Result<UserProfile> ok = await profile.getMe();
    expect(ok, isA<Ok<UserProfile>>());

    // Replay the now-spent refresh token directly against the endpoint.
    final Dio raw = Dio(BaseOptions(baseUrl: ApiConfig.apiBase));
    Object? status;
    try {
      await raw.post<dynamic>(
        '/auth/refresh',
        data: <String, dynamic>{'refresh': spent},
      );
    } on DioException catch (e) {
      status = e.response?.statusCode;
    }
    expect(status, 401, reason: 'a spent refresh token is revoked');
  });

  test('logout revokes the session server-side', () async {
    await registerFresh();
    final String refresh = tokens.refreshToken!;
    final Result<void> r = await auth.logout();
    expect(r, isA<Ok<void>>());
    expect(tokens.hasSession, isFalse);

    // The revoked refresh token can no longer mint a session.
    final Dio raw = Dio(BaseOptions(baseUrl: ApiConfig.apiBase));
    Object? status;
    try {
      await raw.post<dynamic>(
        '/auth/refresh',
        data: <String, dynamic>{'refresh': refresh},
      );
    } on DioException catch (e) {
      status = e.response?.statusCode;
    }
    expect(status, 401, reason: 'logout revoked the refresh token');
  });
}
