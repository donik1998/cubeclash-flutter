import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/timer/data/local/local_solve_store.dart';
import '../../features/timer/data/repositories/fake_solve_repository.dart';
import '../../features/timer/data/repositories/local_solve_repository.dart';
import '../../features/timer/data/repositories/solve_repository_impl.dart';
import '../../features/timer/domain/repositories/solve_repository.dart';
import '../../features/timer/domain/usecases/generate_scramble.dart';
import '../../features/timer/presentation/bloc/timer_bloc.dart';
import '../../features/timer/presentation/cubit/history_cubit.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/repositories/fake_auth_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/profile/data/repositories/fake_profile_repository.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/data/repositories/settings_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/cubit/friends_cubit.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';
import '../../features/profile/presentation/cubit/settings_cubit.dart';
import '../../features/race/data/fake_race_gateway.dart';
import '../../features/race/data/repositories/fake_race_lobby_repository.dart';
import '../../features/race/data/repositories/fake_tournament_repository.dart';
import '../../features/race/data/repositories/race_lobby_repository_impl.dart';
import '../../features/race/data/repositories/tournament_repository_impl.dart';
import '../../features/race/domain/repositories/race_lobby_repository.dart';
import '../../features/race/domain/repositories/tournament_repository.dart';
import '../../features/race/presentation/bloc/race_bloc.dart';
import '../../features/race/presentation/cubit/lobby_cubit.dart';
import '../../features/race/presentation/cubit/tournaments_cubit.dart';
import '../../features/stats/data/repositories/fake_stats_repository.dart';
import '../../features/stats/data/repositories/stats_repository_impl.dart';
import '../../features/stats/domain/repositories/stats_repository.dart';
import '../../features/stats/presentation/cubit/player_profile_cubit.dart';
import '../../features/stats/presentation/cubit/stats_cubit.dart';
import '../../features/timer/presentation/cubit/solve_detail_cubit.dart';
import '../analytics/analytics_service.dart';
import '../network/auth_interceptor.dart';
import '../network/dio_client.dart';
import '../network/token_storage.dart';
import '../realtime/race_gateway.dart';
import '../router/app_router.dart';
import '../router/immersive_controller.dart';
import '../util/ticker.dart';

/// Service locator.
final GetIt sl = GetIt.instance;

/// Fake data vs the live backend.
///
/// `cubeclash-backend` does not exist yet, so every feature ships two
/// implementations of its real repository interface and this flag picks one.
/// The whole app is demoable today with `flutter run`; pointing it at a live
/// server is one build flag, not a refactor:
///
///   flutter run --dart-define=USE_FAKE_DATA=false \
///               --dart-define=API_BASE_URL=https://api.cubeclash.app
///
/// The interfaces are written against the documented contract, so the real
/// implementations compile and are reviewable before the server answers.
const bool kUseFakeData = bool.fromEnvironment(
  'USE_FAKE_DATA',
  defaultValue: true,
);

/// Within the no-backend build: persist real solves locally, or serve the
/// ephemeral seeded demo.
///
/// The shipping app persists solves + the last-selected event to
/// SharedPreferences (`LocalSolveRepository`) so they survive a relaunch.
/// Goldens and screenshots pass `--dart-define=USE_LOCAL_STORE=false` to get
/// the deterministic seeded history (`FakeSolveRepository`) instead — no
/// platform channel, reproducible data. Ignored when `kUseFakeData` is false;
/// the real backend owns history then.
const bool kUseLocalStore = bool.fromEnvironment(
  'USE_LOCAL_STORE',
  defaultValue: true,
);

/// Whether to bring up Firebase and send analytics at all.
///
/// On by default; `--dart-define=ENABLE_ANALYTICS=false` turns the app into a
/// telemetry-free build (useful for local debugging and for anyone running the
/// demo who should not pollute the production property). Independent of
/// `kUseFakeData` — a fake-data build is still a real app session worth
/// measuring, and a live-backend build may still want analytics off.
const bool kEnableAnalytics = bool.fromEnvironment(
  'ENABLE_ANALYTICS',
  defaultValue: true,
);

/// How often the fake repositories pretend a read failed, so the loading and
/// error states can be exercised without a backend.
///
/// **Zero by default** — the clean demo never errors. Set a small value (e.g.
/// `0.15`) to show the retry / error UI off:
///
///   flutter run --dart-define=DEMO_READ_FAILURE_RATE=0.15
///
/// Ignored entirely when `kUseFakeData` is false; the real repositories surface
/// real transport errors.
final double kDemoReadFailureRate = double.tryParse(
      const String.fromEnvironment('DEMO_READ_FAILURE_RATE'),
    ) ??
    0;

/// Manual DI wiring. When the injectable codegen upgrade lands this becomes a
/// generated `configureDependencies()` — see docs/Flutter App Architecture.
///
/// [useLocalStore] chooses the no-backend solve store. It defaults to **false**
/// — the deterministic seeded fake — so tests and goldens get stable data and
/// never touch the SharedPreferences platform channel (which hangs under
/// `flutter test`). `main()` opts into local persistence via `kUseLocalStore`.
///
/// [analytics] defaults to [NoopAnalytics] for the same reason: a test must
/// never emit a network event. `main()` passes the Firebase implementation once
/// `Firebase.initializeApp` has actually succeeded — never before, because
/// `FirebaseAnalytics.instance` throws without an initialised app.
Future<void> configureDependencies({
  bool useLocalStore = false,
  AnalyticsService? analytics,
}) async {
  // --- Core ------------------------------------------------------------------
  sl
    // Real tokens go to the Keychain / Keystore; the fake-data build has no
    // session worth protecting and no platform channel in tests.
    ..registerLazySingleton<TokenStorage>(
      () => kUseFakeData ? InMemoryTokenStorage() : const SecureTokenStorage(),
    )
    ..registerLazySingleton<TokenStore>(() => TokenStore(sl<TokenStorage>()))
    ..registerLazySingleton<DioClient>(() => DioClient(sl<TokenStore>()))
    // The race is the one feature a static fake can't cover — it's a
    // conversation over time — so the fake is a scripted gateway that emits the
    // same events in the same order as the socket one.
    ..registerLazySingleton<RaceGateway>(
      () => kUseFakeData ? FakeRaceGateway() : SocketRaceGateway(),
    )
    ..registerLazySingleton<AnalyticsService>(
      () => analytics ?? const NoopAnalytics(),
    )
    ..registerLazySingleton<Ticker>(() => const RealTicker())
    ..registerLazySingleton<ImmersiveController>(ImmersiveController.new)
    // The router guards on the TokenStore, so it is built from it here rather
    // than being a process-wide static that could outlive its store.
    ..registerLazySingleton<GoRouter>(
      () => AppRouter.create(sl<TokenStore>()),
    );

  // --- Timer -----------------------------------------------------------------
  sl
    ..registerLazySingleton<GenerateScramble>(GenerateScramble.new)
    // The device's local persistence. Only touched when `useLocalStore` selects
    // it below, so the seeded/test path never reaches SharedPreferences.
    ..registerLazySingleton<LocalSolveStore>(LocalSolveStore.new)
    ..registerLazySingleton<SolveRepository>(
      () {
        if (!kUseFakeData) return SolveRepositoryImpl(sl<DioClient>());
        return useLocalStore
            ? LocalSolveRepository(sl<LocalSolveStore>())
            : FakeSolveRepository(readFailureRate: kDemoReadFailureRate);
      },
    )
    // Factories: a screen's bloc is created with the screen and closed with it.
    ..registerFactory<TimerBloc>(
      () => TimerBloc(
        repository: sl<SolveRepository>(),
        generateScramble: sl<GenerateScramble>(),
        analytics: sl<AnalyticsService>(),
        ticker: sl<Ticker>(),
        // Only the persisting build remembers the last event; the seeded/test
        // build has no store to read and defaults to 3×3.
        lastEventStore: useLocalStore ? sl<LocalSolveStore>() : null,
      ),
    )
    ..registerFactory<SolveDetailCubit>(
      () => SolveDetailCubit(
        repository: sl<SolveRepository>(),
        analytics: sl<AnalyticsService>(),
      ),
    )
    ..registerFactory<HistoryCubit>(
      () => HistoryCubit(repository: sl<SolveRepository>()),
    );

  // --- Stats -----------------------------------------------------------------
  sl
    ..registerLazySingleton<StatsRepository>(
      () => kUseFakeData
          ? FakeStatsRepository(readFailureRate: kDemoReadFailureRate)
          : StatsRepositoryImpl(sl<DioClient>()),
    )
    ..registerFactory<StatsCubit>(
      () => StatsCubit(
        repository: sl<StatsRepository>(),
        analytics: sl<AnalyticsService>(),
      ),
    )
    ..registerFactory<PlayerProfileCubit>(
      () => PlayerProfileCubit(repository: sl<StatsRepository>()),
    );

  // --- Auth ------------------------------------------------------------------
  sl
    ..registerLazySingleton<AuthRepository>(
      () => kUseFakeData
          ? FakeAuthRepository(sl<TokenStore>())
          : AuthRepositoryImpl(sl<DioClient>(), sl<TokenStore>()),
    )
    ..registerFactory<AuthCubit>(
      () => AuthCubit(repository: sl<AuthRepository>()),
    );

  // --- Profile / settings ----------------------------------------------------
  sl
    // Settings are device preferences, not account data — no fake/real split,
    // and they must work with no backend at all.
    ..registerLazySingleton<SettingsRepository>(SettingsRepositoryImpl.new)
    ..registerLazySingleton<ProfileRepository>(
      () => kUseFakeData
          ? FakeProfileRepository(readFailureRate: kDemoReadFailureRate)
          : ProfileRepositoryImpl(sl<DioClient>(), sl<TokenStore>()),
    )
    // A singleton: the theme is one of its values, so it is provided above
    // MaterialApp and outlives every screen.
    ..registerLazySingleton<SettingsCubit>(
      () => SettingsCubit(
        repository: sl<SettingsRepository>(),
        analytics: sl<AnalyticsService>(),
      ),
    )
    ..registerFactory<ProfileCubit>(
      () => ProfileCubit(repository: sl<ProfileRepository>()),
    )
    ..registerFactory<FriendsCubit>(
      () => FriendsCubit(repository: sl<ProfileRepository>()),
    );

  // --- Race ------------------------------------------------------------------
  // A singleton, unlike the other blocs: a race outlives the lobby widget that
  // started it (the Live Race and Result screens are separate routes), so its
  // state cannot be tied to one screen's lifetime.
  sl.registerLazySingleton<RaceBloc>(
    () => RaceBloc(
      gateway: sl<RaceGateway>(),
      analytics: sl<AnalyticsService>(),
      ticker: sl<Ticker>(),
    ),
  );

  sl
    ..registerLazySingleton<TournamentRepository>(
      () => kUseFakeData
          ? FakeTournamentRepository(readFailureRate: kDemoReadFailureRate)
          : TournamentRepositoryImpl(sl<DioClient>()),
    )
    ..registerFactory<TournamentsCubit>(
      () => TournamentsCubit(repository: sl<TournamentRepository>()),
    )
    ..registerFactory<TournamentDetailCubit>(
      () => TournamentDetailCubit(repository: sl<TournamentRepository>()),
    )
    ..registerLazySingleton<RaceLobbyRepository>(
      () => kUseFakeData
          ? FakeRaceLobbyRepository(readFailureRate: kDemoReadFailureRate)
          : RaceLobbyRepositoryImpl(sl<DioClient>()),
    )
    ..registerFactory<LobbyCubit>(
      () => LobbyCubit(repository: sl<RaceLobbyRepository>()),
    );
}

/// Tears the locator down. Tests call this between cases so a stale singleton
/// (a fake repository holding a closed stream, say) can't leak across them.
Future<void> resetDependencies() => sl.reset();
