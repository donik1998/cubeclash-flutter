import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget. Token-driven light/dark themes flip via [ThemeMode]; routing is
/// delegated to go_router (4-tab shell).
class CubeClashApp extends StatelessWidget {
  const CubeClashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CubeClash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system, // TODO(settings): bind to the theme toggle.
      routerConfig: AppRouter.router,
    );
  }
}
