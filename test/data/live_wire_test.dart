import 'package:cubeclash/core/error/failures.dart';
import 'package:cubeclash/core/error/result.dart';
import 'package:cubeclash/core/network/auth_interceptor.dart';
import 'package:cubeclash/core/network/dio_client.dart';
import 'package:cubeclash/core/network/token_storage.dart';
import 'package:cubeclash/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:cubeclash/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:cubeclash/features/profile/data/repositories/profile_summary_repository_impl.dart';
import 'package:cubeclash/features/profile/domain/entities/profile_summary.dart';
import 'package:cubeclash/features/profile/domain/entities/user_profile.dart';
import 'package:cubeclash/features/stats/data/repositories/stats_repository_impl.dart';
import 'package:cubeclash/features/stats/domain/entities/leaderboard_entry.dart';
import 'package:cubeclash/features/stats/domain/entities/player_stats.dart';
import 'package:cubeclash/features/timer/data/repositories/solve_repository_impl.dart';
import 'package:cubeclash/features/timer/domain/entities/penalty.dart';
import 'package:cubeclash/core/network/page.dart';
import 'package:cubeclash/features/timer/domain/entities/solve.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixture_adapter.dart';
import '../support/fixtures.dart';

/// Parses **real captured server bytes** (`test/fixtures/api/`) through the real
/// repository implementations over a real Dio. This is the offline half of the
/// live-wiring proof: if the client's DTO/mapper drifts from what the server
/// actually sends, it breaks here rather than in production.
void main() {
  /// A [DioClient] whose transport serves [response] for any request. Tokens
  /// are seeded so the interceptor attaches a Bearer header; leave [withSession]
  /// false to test the no-token / error paths without tripping a refresh.
  Future<DioClient> clientServing(
    ResponseBody Function(RequestOptions) response, {
    bool withSession = true,
  }) async {
    final TokenStore tokens = TokenStore(InMemoryTokenStorage());
    await tokens.restore();
    if (withSession) {
      await tokens.setTokens(access: 'access-jwt', refresh: 'refresh-jwt');
    }
    final DioClient client = DioClient(tokens);
    final FixtureAdapter adapter = FixtureAdapter(response);
    client.dio.httpClientAdapter = adapter;
    _adapters[client] = adapter;
    _tokenStores[client] = tokens;
    return client;
  }

  group('auth — auth_register.json / auth_login.json', () {
    test('register stores the returned token pair', () async {
      final Map<String, dynamic> fixture = loadApiFixture('auth_register');
      final DioClient client =
          await clientServing((_) => jsonResponse(fixture), withSession: false);
      final TokenStore tokens = _tokensOf(client);
      final AuthRepositoryImpl repo = AuthRepositoryImpl(client, tokens);

      final Result<void> result = await repo.register(
        email: 'fx@ex.com',
        password: 'hunter2hunter2',
        displayName: 'fixture_user',
      );

      expect(result, isA<Ok<void>>());
      expect(tokens.accessToken, (fixture['tokens'] as Map)['access']);
      expect(tokens.refreshToken, (fixture['tokens'] as Map)['refresh']);
      expect(tokens.hasSession, isTrue);
      // Sent to the documented path with snake_case body.
      final RequestOptions sent = _adapters[client]!.requests.single;
      expect(sent.path, '/auth/register');
      expect((sent.data as Map)['display_name'], 'fixture_user');
    });

    test('login stores the returned token pair', () async {
      final Map<String, dynamic> fixture = loadApiFixture('auth_login');
      final DioClient client =
          await clientServing((_) => jsonResponse(fixture), withSession: false);
      final TokenStore tokens = _tokensOf(client);
      final AuthRepositoryImpl repo = AuthRepositoryImpl(client, tokens);

      final Result<void> result =
          await repo.login(email: 'kian_r@ex.com', password: 'hunter2hunter2');

      expect(result, isA<Ok<void>>());
      expect(tokens.accessToken, (fixture['tokens'] as Map)['access']);
      expect(tokens.refreshToken, (fixture['tokens'] as Map)['refresh']);
    });
  });

  group('logout — sends the refresh token in the body (live contract)', () {
    test('AuthRepository.logout posts {refresh} and clears the session',
        () async {
      final DioClient client = await clientServing((_) => noContent());
      final TokenStore tokens = _tokensOf(client);
      final AuthRepositoryImpl repo = AuthRepositoryImpl(client, tokens);

      final Result<void> result = await repo.logout();

      expect(result, isA<Ok<void>>());
      final RequestOptions sent = _adapters[client]!.requests.single;
      expect(sent.path, '/auth/logout');
      expect((sent.data as Map)['refresh'], 'refresh-jwt',
          reason:
              'the live server revokes by refresh token and 400s without it');
      expect(tokens.hasSession, isFalse);
    });

    test('ProfileRepository.logout posts {refresh} too', () async {
      final DioClient client = await clientServing((_) => noContent());
      final TokenStore tokens = _tokensOf(client);
      final ProfileRepositoryImpl repo = ProfileRepositoryImpl(client, tokens);

      await repo.logout();

      final RequestOptions sent = _adapters[client]!.requests.single;
      expect(sent.path, '/auth/logout');
      expect((sent.data as Map)['refresh'], 'refresh-jwt');
      expect(tokens.hasSession, isFalse);
    });
  });

  group('profile — me.json', () {
    test('getMe parses the wrapped user, including email and country',
        () async {
      final Map<String, dynamic> fixture = loadApiFixture('me');
      final DioClient client =
          await clientServing((_) => jsonResponse(fixture));
      final ProfileRepositoryImpl repo =
          ProfileRepositoryImpl(client, _tokensOf(client));

      final Result<UserProfile> result = await repo.getMe();
      final UserProfile me = (result as Ok<UserProfile>).value;

      final Map<String, dynamic> user =
          Map<String, dynamic>.from(fixture['user'] as Map);
      expect(me.id, user['id']);
      expect(me.displayName, 'kian_r');
      expect(me.email, user['email']);
      expect(me.countryCode, 'IR');
      expect(me.elo, 1000);
    });
  });

  group('stats — stats.json (the ao5/ao12/ao100 regression)', () {
    test('maps ao5/ao12/ao100 onto the domain best-ao fields', () async {
      final Map<String, dynamic> fixture = loadApiFixture('stats');
      final DioClient client =
          await clientServing((_) => jsonResponse(fixture));
      final StatsRepositoryImpl repo = StatsRepositoryImpl(client);

      final Result<PlayerStats> result = await repo.getStats();
      final PlayerStats stats = (result as Ok<PlayerStats>).value;

      // Assertions are derived FROM the fixture, not hardcoded: these files are
      // regenerated against a live server, so pinning literals here means every
      // refresh breaks the suite for no reason. What matters is that the
      // *wire keys* map onto the right domain fields.
      expect(stats.event, fixture['event']);
      expect(stats.bestSingleMs, fixture['best_single_ms']);
      expect(stats.bestAo5Ms, fixture['ao5'],
          reason: 'wire key is ao5, not best_ao5_ms — the original bug');
      expect(stats.bestAo12Ms, fixture['ao12'], reason: 'wire key is ao12');
      expect(stats.bestAo100Ms, fixture['ao100'], reason: 'wire key is ao100');
      expect(stats.solveCount, fixture['solve_count']);

      // progress/distribution are now served (added after the first live pass).
      final List<dynamic> progress = fixture['progress'] as List<dynamic>;
      final List<dynamic> buckets = fixture['distribution'] as List<dynamic>;
      expect(stats.progress, hasLength(progress.length));
      expect(stats.distribution, hasLength(buckets.length));
      if (stats.progress.isNotEmpty) {
        expect(stats.progress.first.bestMs,
            (progress.first as Map<String, dynamic>)['best_ms']);
        expect(stats.progress.first.solveCount,
            (progress.first as Map<String, dynamic>)['solve_count']);
      }
      for (int i = 0; i < stats.distribution.length - 1; i++) {
        expect(stats.distribution[i].toMs, stats.distribution[i + 1].fromMs,
            reason: 'histogram buckets must be contiguous');
      }
    });
  });

  group('stats — users_public.json', () {
    test('getPlayer parses the minimal public user (bests/h2h absent)',
        () async {
      // Hand-written identity-only shape: what a user with no solves and no
      // shared races returns, and what the endpoint returned before it was
      // widened. Proves the parse stays lenient when the fields are absent.
      final Map<String, dynamic> fixture =
          loadApiFixture('users_public_minimal');
      final DioClient client =
          await clientServing((_) => jsonResponse(fixture));
      final StatsRepositoryImpl repo = StatsRepositoryImpl(client);

      final Result<PlayerProfile> result = await repo.getPlayer(
        'b4f22257-01f9-4096-b7e5-1a2203c904c5',
      );
      final PlayerProfile p = (result as Ok<PlayerProfile>).value;

      expect(p.displayName, 'kian_r');
      expect(p.countryCode, 'IR');
      expect(p.elo, 1000);
      expect(p.bestSingleMs, isNull);
      expect(p.headToHead, isNull);
    });
  });

  group('stats — users_public.json (widened)', () {
    test('getPlayer parses bests and head-to-head from the live shape',
        () async {
      final Map<String, dynamic> fixture = loadApiFixture('users_public');
      final Map<String, dynamic> user =
          fixture['user'] as Map<String, dynamic>;
      final DioClient client =
          await clientServing((_) => jsonResponse(fixture));
      final StatsRepositoryImpl repo = StatsRepositoryImpl(client);

      final Result<PlayerProfile> result =
          await repo.getPlayer(user['id'] as String);
      final PlayerProfile p = (result as Ok<PlayerProfile>).value;

      expect(p.displayName, user['display_name']);
      // The averages are named ao5/ao12 here too, matching GET /stats.
      expect(p.bestSingleMs, user['best_single_ms']);
      expect(p.bestAo5Ms, user['ao5'],
          reason: 'profile uses ao5, consistent with /stats');
      expect(p.bestAo12Ms, user['ao12']);
      // No email may ever appear on a public profile.
      expect(user.containsKey('email'), isFalse);
    });
  });

  group('stats — leaderboard.json', () {
    test('parses items, viewer and value_ms→timeMs', () async {
      final Map<String, dynamic> fixture = loadApiFixture('leaderboard');
      final DioClient client =
          await clientServing((_) => jsonResponse(fixture));
      final StatsRepositoryImpl repo = StatsRepositoryImpl(client);

      final Result<Leaderboard> result = await repo.getLeaderboard();
      final Leaderboard board = (result as Ok<Leaderboard>).value;

      expect(board.entries, hasLength(4));
      expect(board.entries.first.displayName, 'kian_r');
      expect(board.entries.first.timeMs, 6289,
          reason: 'value_ms maps to timeMs');
      expect(board.nextCursor, isNull);
      expect(board.viewer, isNotNull);
      expect(board.viewer!.isCurrentUser, isTrue);
      expect(board.viewer!.rank, 1);
    });
  });

  group('profile summary — me_profile.json', () {
    test('parses user, rank position and stats', () async {
      final Map<String, dynamic> fixture = loadApiFixture('me_profile');
      final DioClient client =
          await clientServing((_) => jsonResponse(fixture));
      final ProfileSummaryRepositoryImpl repo =
          ProfileSummaryRepositoryImpl(client);

      final Result<ProfileSummary> result = await repo.getProfileSummary();
      final ProfileSummary s = (result as Ok<ProfileSummary>).value;

      expect(s.displayName, 'kian_r');
      expect(s.elo, 1000);
      expect(s.rank?.position, 1);
      expect(s.totalSolves, 12);
      expect(s.winRate, isNull, reason: 'win_rate is null in the fixture');
      expect(s.friendCount, 0);
    });
  });

  group('solves — solves_list.json', () {
    test('getHistory parses the page, the DNF penalty and the cursor',
        () async {
      final Map<String, dynamic> fixture = loadApiFixture('solves_list');
      final DioClient client =
          await clientServing((_) => jsonResponse(fixture));
      final SolveRepositoryImpl repo = SolveRepositoryImpl(client);

      final Result<Page<Solve>> result = await repo.getHistory();
      final Page<Solve> page = (result as Ok<Page<Solve>>).value;

      expect(page.items, hasLength(5));
      expect(page.items.first.timeMs, 6997);
      expect(page.items.first.event, '3x3');
      // The second seeded solve is the DNF.
      expect(page.items[1].penalty, Penalty.dnf);
      expect(page.items[1].isDnf, isTrue);
      expect(page.nextCursor, isNotNull);
      expect(page.hasMore, isTrue);
    });

    test('addSolve parses the wrapped {solve} create response', () async {
      final Map<String, dynamic> item = Map<String, dynamic>.from(
        (loadApiFixture('solves_list')['items'] as List).first as Map,
      );
      final DioClient client = await clientServing(
        (_) => jsonResponse(<String, dynamic>{'solve': item}),
      );
      final SolveRepositoryImpl repo = SolveRepositoryImpl(client);

      final Result<Solve> result = await repo.addSolve(
        event: '3x3',
        scramble: "R U R' U' F2 L D2 B'",
        timeMs: 6997,
        penalty: Penalty.none,
        solvedAt: DateTime.utc(2026, 7, 28, 9, 18),
        clientId: 'kian_r-s8',
      );

      final Solve solve = (result as Ok<Solve>).value;
      expect(solve.id, item['id']);
      // The POST body carries scramble_source and client_id for idempotency.
      final RequestOptions sent = _adapters[client]!.requests.single;
      expect(sent.path, '/solves');
      expect((sent.data as Map)['scramble_source'], 'random');
      expect((sent.data as Map)['client_id'], 'kian_r-s8');
    });
  });

  group('error envelopes', () {
    test('a 400 validation envelope surfaces its message', () async {
      final Map<String, dynamic> fixture = loadApiFixture('error_validation');
      final DioClient client = await clientServing(
        (_) => jsonResponse(fixture, status: 400),
        withSession: false,
      );
      final StatsRepositoryImpl repo = StatsRepositoryImpl(client);

      final Result<PlayerStats> result = await repo.getStats();
      final Failure failure = (result as Err<PlayerStats>).failure;
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'Request validation failed');
    });

    test('a 401 unauthorized envelope maps to AuthFailure', () async {
      final Map<String, dynamic> fixture = loadApiFixture('error_unauthorized');
      // No session → the interceptor won't try to refresh, so the 401 flows
      // straight through to dioFailure.
      final DioClient client = await clientServing(
        (_) => jsonResponse(fixture, status: 401),
        withSession: false,
      );
      final StatsRepositoryImpl repo = StatsRepositoryImpl(client);

      final Result<Leaderboard> result = await repo.getLeaderboard();
      final Failure failure = (result as Err<Leaderboard>).failure;
      expect(failure, isA<AuthFailure>());
    });

    test('a 400 unknown_event envelope surfaces its message', () async {
      final Map<String, dynamic> fixture =
          loadApiFixture('error_unknown_event');
      final DioClient client = await clientServing(
        (_) => jsonResponse(fixture, status: 400),
        withSession: false,
      );
      final StatsRepositoryImpl repo = StatsRepositoryImpl(client);

      final Result<Leaderboard> result =
          await repo.getLeaderboard(event: '6x7');
      final Failure failure = (result as Err<Leaderboard>).failure;
      expect(failure.message, "Unknown event '6x7'");
    });
  });
}

/// Side-table so a test can reach the [FixtureAdapter] (and its captured
/// requests) and the [TokenStore] behind a [DioClient] without exposing either
/// on the production class.
final Map<DioClient, FixtureAdapter> _adapters = <DioClient, FixtureAdapter>{};
final Map<DioClient, TokenStore> _tokenStores = <DioClient, TokenStore>{};

TokenStore _tokensOf(DioClient client) => _tokenStores[client]!;
