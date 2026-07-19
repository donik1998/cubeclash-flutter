import 'package:get_it/get_it.dart';

import '../../features/timer/data/repositories/fake_solve_repository.dart';
import '../../features/timer/data/repositories/solve_repository_impl.dart';
import '../../features/timer/domain/repositories/solve_repository.dart';
import '../../features/timer/domain/usecases/generate_scramble.dart';
import '../../features/timer/presentation/bloc/timer_bloc.dart';
import '../../features/timer/presentation/cubit/history_cubit.dart';
import '../../features/profile/data/repositories/fake_profile_repository.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/data/repositories/settings_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/cubit/friends_cubit.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';
import '../../features/profile/presentation/cubit/settings_cubit.dart';
import '../../features/race/data/fake_race_gateway.dart';
import '../../features/race/presentation/bloc/race_bloc.dart';
import '../../features/stats/data/repositories/fake_stats_repository.dart';
import '../../features/stats/data/repositories/stats_repository_impl.dart';
import '../../features/stats/domain/repositories/stats_repository.dart';
import '../../features/stats/presentation/cubit/player_profile_cubit.dart';
import '../../features/stats/presentation/cubit/stats_cubit.dart';
import '../../features/timer/presentation/cubit/solve_detail_cubit.dart';
import '../analytics/analytics_service.dart';
import '../network/auth_interceptor.dart';
import '../network/dio_client.dart';
import '../realtime/race_gateway.dart';
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

/// Manual DI wiring. When the injectable codegen upgrade lands this becomes a
/// generated `configureDependencies()` — see docs/Flutter App Architecture.
Future<void> configureDependencies() async {
  // --- Core ------------------------------------------------------------------
  sl
    ..registerLazySingleton<TokenStore>(TokenStore.new)
    ..registerLazySingleton<DioClient>(() => DioClient(sl<TokenStore>()))
    // The race is the one feature a static fake can't cover — it's a
    // conversation over time — so the fake is a scripted gateway that emits the
    // same events in the same order as the socket one.
    ..registerLazySingleton<RaceGateway>(
      () => kUseFakeData ? FakeRaceGateway() : SocketRaceGateway(),
    )
    ..registerLazySingleton<AnalyticsService>(() => const NoopAnalytics())
    ..registerLazySingleton<Ticker>(() => const RealTicker())
    ..registerLazySingleton<ImmersiveController>(ImmersiveController.new);

  // --- Timer -----------------------------------------------------------------
  sl
    ..registerLazySingleton<GenerateScramble>(GenerateScramble.new)
    ..registerLazySingleton<SolveRepository>(
      () => kUseFakeData
          ? FakeSolveRepository()
          : SolveRepositoryImpl(sl<DioClient>()),
    )
    // Factories: a screen's bloc is created with the screen and closed with it.
    ..registerFactory<TimerBloc>(
      () => TimerBloc(
        repository: sl<SolveRepository>(),
        generateScramble: sl<GenerateScramble>(),
        analytics: sl<AnalyticsService>(),
        ticker: sl<Ticker>(),
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
          ? FakeStatsRepository()
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

  // --- Profile / settings ----------------------------------------------------
  sl
    // Settings are device preferences, not account data — no fake/real split,
    // and they must work with no backend at all.
    ..registerLazySingleton<SettingsRepository>(SettingsRepositoryImpl.new)
    ..registerLazySingleton<ProfileRepository>(
      () => kUseFakeData
          ? FakeProfileRepository()
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
}

/// Tears the locator down. Tests call this between cases so a stale singleton
/// (a fake repository holding a closed stream, say) can't leak across them.
Future<void> resetDependencies() => sl.reset();
