import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/race/presentation/pages/race_page.dart';
import '../../features/stats/presentation/pages/stats_page.dart';
import '../../features/timer/presentation/pages/timer_page.dart';
import 'scaffold_with_nav_bar.dart';

/// App routing. A [StatefulShellRoute] gives each of the 4 tabs its own
/// navigation stack (state preserved per tab). Immersive flows (a running
/// solve, a live race) become full-screen routes outside the shell later.
class AppRouter {
  const AppRouter._();

  static final GlobalKey<NavigatorState> _timerNav =
      GlobalKey<NavigatorState>(debugLabel: 'timer');
  static final GlobalKey<NavigatorState> _raceNav =
      GlobalKey<NavigatorState>(debugLabel: 'race');
  static final GlobalKey<NavigatorState> _statsNav =
      GlobalKey<NavigatorState>(debugLabel: 'stats');
  static final GlobalKey<NavigatorState> _youNav =
      GlobalKey<NavigatorState>(debugLabel: 'you');

  static final GoRouter router = GoRouter(
    initialLocation: '/timer',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: _timerNav,
            routes: <RouteBase>[
              GoRoute(
                  path: '/timer',
                  builder: (context, state) => const TimerPage()),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _raceNav,
            routes: <RouteBase>[
              GoRoute(
                  path: '/race', builder: (context, state) => const RacePage()),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _statsNav,
            routes: <RouteBase>[
              GoRoute(
                  path: '/stats',
                  builder: (context, state) => const StatsPage()),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _youNav,
            routes: <RouteBase>[
              GoRoute(
                  path: '/you',
                  builder: (context, state) => const ProfilePage()),
            ],
          ),
        ],
      ),
    ],
  );
}
