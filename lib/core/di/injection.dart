import 'package:get_it/get_it.dart';

import '../analytics/analytics_service.dart';
import '../network/auth_interceptor.dart';
import '../network/dio_client.dart';
import '../realtime/race_gateway.dart';

/// Service locator.
final GetIt sl = GetIt.instance;

/// Manual DI wiring. When the injectable codegen upgrade lands this becomes a
/// generated `configureDependencies()` — see docs/Flutter App Architecture.
Future<void> configureDependencies() async {
  sl
    ..registerLazySingleton<TokenStore>(TokenStore.new)
    ..registerLazySingleton<DioClient>(() => DioClient(sl<TokenStore>()))
    ..registerLazySingleton<RaceGateway>(RaceGateway.new)
    ..registerLazySingleton<AnalyticsService>(() => const NoopAnalytics());

  // Feature registrations are added here as they are implemented, e.g.:
  //   sl.registerFactory<TimerCubit>(() => TimerCubit(sl()));
}
