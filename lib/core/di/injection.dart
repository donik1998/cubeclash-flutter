import 'package:get_it/get_it.dart';

import '../../features/timer/data/repositories/fake_solve_repository.dart';
import '../../features/timer/data/repositories/solve_repository_impl.dart';
import '../../features/timer/domain/repositories/solve_repository.dart';
import '../../features/timer/domain/usecases/generate_scramble.dart';
import '../../features/timer/presentation/bloc/timer_bloc.dart';
import '../../features/timer/presentation/cubit/history_cubit.dart';
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
    ..registerLazySingleton<RaceGateway>(RaceGateway.new)
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
}

/// Tears the locator down. Tests call this between cases so a stale singleton
/// (a fake repository holding a closed stream, say) can't leak across them.
Future<void> resetDependencies() => sl.reset();
