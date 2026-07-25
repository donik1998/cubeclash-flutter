import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/profile_setup_page.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/welcome_page.dart';
import '../../features/profile/presentation/pages/friends_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/race/presentation/pages/live_race_page.dart';
import '../../features/race/presentation/pages/race_page.dart';
import '../../features/race/presentation/pages/tournament_detail_page.dart';
import '../../features/stats/presentation/pages/player_profile_page.dart';
import '../../features/stats/presentation/pages/stats_page.dart';
import '../../features/timer/presentation/pages/session_history_page.dart';
import '../../features/timer/presentation/pages/solve_detail_page.dart';
import '../../features/timer/presentation/pages/timer_page.dart';
import '../network/auth_interceptor.dart';
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

  /// Locations that do not require a session.
  static const String _authRoot = '/auth';

  /// Builds the router.
  ///
  /// A factory rather than a `static final`: the router captures the
  /// [TokenStore] it guards on, so a process-wide instance would outlive the
  /// store it was built with — invisible in production (one app, one DI
  /// container) and a source of stale-state bugs everywhere else. It is
  /// registered as a singleton in `injection.dart` and torn down with the rest.
  static GoRouter create(TokenStore tokens) => GoRouter(
        navigatorKey: _rootNav,
        initialLocation: '/timer',

        // Rebuilds [redirect] whenever the session appears or disappears —
        // including when the AuthInterceptor gives up on a refresh mid-session and
        // clears the tokens, which is what makes an expired session bounce the
        // user out rather than leaving them on a screen that can't load.
        refreshListenable: tokens,

        redirect: (BuildContext context, GoRouterState state) {
          // Hold still until the persisted session has been read, so a signed-in
          // user isn't flashed the welcome screen on a cold start.
          if (!tokens.isRestored) return null;

          final bool onAuthScreen = state.matchedLocation.startsWith(_authRoot);

          if (!tokens.hasSession) {
            return onAuthScreen ? null : _authRoot;
          }
          // Signed in but sitting on the auth stack — send them to the app.
          // Profile setup is the exception: you have a session there by design,
          // and it's the last step of registration.
          if (onAuthScreen && state.matchedLocation != '/auth/setup') {
            return '/timer';
          }
          return null;
        },

        routes: <RouteBase>[
          // --- Auth stack: outside the shell, no nav bar ---------------------------
          GoRoute(
            path: _authRoot,
            builder: (context, state) => const WelcomePage(),
            routes: <RouteBase>[
              GoRoute(
                path: 'login',
                builder: (context, state) =>
                    const SignInPage(isRegister: false),
              ),
              GoRoute(
                path: 'register',
                builder: (context, state) => const SignInPage(isRegister: true),
              ),
              GoRoute(
                path: 'setup',
                builder: (context, state) => const ProfileSetupPage(),
              ),
            ],
          ),
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
                      GoRoute(
                        path: 'tournament/:id',
                        parentNavigatorKey: _rootNav,
                        builder: (context, state) => TournamentDetailPage(
                          id: state.pathParameters['id']!,
                        ),
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
