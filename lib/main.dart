import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/analytics/analytics_service.dart';
import 'core/analytics/firebase_analytics_service.dart';
import 'core/di/injection.dart';
import 'core/network/auth_interceptor.dart';
import 'features/profile/presentation/cubit/settings_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Analytics is resolved before DI so the locator can be handed a binding that
  // is already known to work, rather than one that throws on first use.
  final AnalyticsService analytics = await _initAnalytics();

  // The shipping app opts into local persistence — solves and the last-selected
  // event survive a relaunch. `--dart-define=USE_LOCAL_STORE=false` falls back
  // to the deterministic seeded demo for screenshots.
  await configureDependencies(
    useLocalStore: kUseLocalStore,
    analytics: analytics,
  );

  // Both restores happen before the first frame:
  //  * settings, or the app paints in the system theme then snaps to the
  //    user's choice;
  //  * tokens, or the router's guard sees "no session" and flashes the
  //    welcome screen at someone who is already signed in.
  await Future.wait<void>(<Future<void>>[
    sl<SettingsCubit>().load(),
    sl<TokenStore>().restore(),
  ]);

  runApp(const CubeClashApp());
}

/// Brings Firebase up and returns the analytics binding to use.
///
/// **Deliberately failure-tolerant.** Firebase needs native config
/// (`google-services.json` / `GoogleService-Info.plist`, written by
/// `flutterfire configure`); without it `initializeApp` throws. Analytics is
/// telemetry, not a feature, so a missing or broken Firebase setup degrades to
/// [NoopAnalytics] and the app launches normally. The alternative — a crash on
/// a cold start because a measurement SDK could not reach Google — would be a
/// far worse bug than losing an event.
Future<AnalyticsService> _initAnalytics() async {
  if (!kEnableAnalytics) return const NoopAnalytics();

  try {
    await Firebase.initializeApp();
    return FirebaseAnalyticsService.instance();
  } catch (_) {
    return const NoopAnalytics();
  }
}
