import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/profile/presentation/pages/friends_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/race/presentation/pages/live_race_page.dart';
import '../../features/race/presentation/pages/race_page.dart';
import '../../features/stats/presentation/pages/player_profile_page.dart';
import '../../features/stats/presentation/pages/stats_page.dart';
import '../../features/timer/presentation/pages/session_history_page.dart';
import '../../features/timer/presentation/pages/solve_detail_page.dart';
import '../../features/timer/presentation/pages/timer_page.dart';
import 'scaffold_with_nav_bar.dart';

/// App routing. A [StatefulShellRoute] gives each of the 4 tabs its own
/// navigation stack (state preserved per tab). Immersive flows (a running
/// solve, a live race) become full-screen routes outside the shell later.
class AppRouter {
  const AppRouter._();

  /// The root navigator. Routes that specify it as their parent are pushed
  /// **above** the shell, so they are full-screen with no bottom nav.
  static final GlobalKey<NavigatorState> _rootNav =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GlobalKey<NavigatorState> _timerNav =
      GlobalKey<NavigatorState>(debugLabel: 'timer');
  static final GlobalKey<NavigatorState> _raceNav =
      GlobalKey<NavigatorState>(debugLabel: 'race');
  static final GlobalKey<NavigatorState> _statsNav =
      GlobalKey<NavigatorState>(debugLabel: 'stats');
  static final GlobalKey<NavigatorState> _youNav =
      GlobalKey<NavigatorState>(debugLabel: 'you');

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNav,
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
                builder: (context, state) => const TimerPage(),
                routes: <RouteBase>[
                  // Pushed above the shell (parentNavigatorKey: root) so these
                  // are full-screen — no nav bar to mis-tap mid-review.
                  GoRoute(
                    path: 'history',
                    parentNavigatorKey: _rootNav,
                    builder: (context, state) => const SessionHistoryPage(),
                  ),
                  GoRoute(
                    path: 'solve/:id',
                    parentNavigatorKey: _rootNav,
                    builder: (context, state) => SolveDetailPage(
                      solveId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _raceNav,
            routes: <RouteBase>[
              GoRoute(
                path: '/race',
                builder: (context, state) => const RacePage(),
                routes: <RouteBase>[
                  // Genuinely outside the shell: the live race is a different
                  // screen, the nav bar must not exist while you're solving,
                  // and back is blocked mid-solve (see PopScope there).
                  GoRoute(
                    path: 'live',
                    parentNavigatorKey: _rootNav,
                    builder: (context, state) => const LiveRacePage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _statsNav,
            routes: <RouteBase>[
              GoRoute(
                path: '/stats',
                builder: (context, state) => const StatsPage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'player/:id',
                    parentNavigatorKey: _rootNav,
                    builder: (context, state) => PlayerProfilePage(
                      userId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _youNav,
            routes: <RouteBase>[
              GoRoute(
                path: '/you',
                builder: (context, state) => const ProfilePage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'settings',
                    parentNavigatorKey: _rootNav,
                    builder: (context, state) => const SettingsPage(),
                  ),
                  GoRoute(
                    path: 'friends',
                    parentNavigatorKey: _rootNav,
                    builder: (context, state) => const FriendsPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
