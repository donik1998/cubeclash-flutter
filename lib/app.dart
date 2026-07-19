import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/domain/entities/app_settings.dart';
import 'features/profile/presentation/cubit/settings_cubit.dart';

/// Root widget.
///
/// [SettingsCubit] is provided **above** [MaterialApp] because the theme is one
/// of its values — an app-wide concern, not screen state. It is loaded during
/// bootstrap (`main.dart`) before the first frame, so a user who chose dark
/// mode never sees a flash of light.
class CubeClashApp extends StatelessWidget {
  const CubeClashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SettingsCubit>.value(
      value: sl<SettingsCubit>(),
      child: BlocBuilder<SettingsCubit, AppSettings>(
        buildWhen: (AppSettings a, AppSettings b) => a.themeMode != b.themeMode,
        builder: (BuildContext context, AppSettings settings) {
          return MaterialApp.router(
            title: 'CubeClash',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: switch (settings.themeMode) {
              AppThemeMode.system => ThemeMode.system,
              AppThemeMode.light => ThemeMode.light,
              AppThemeMode.dark => ThemeMode.dark,
            },
            routerConfig: sl<GoRouter>(),
          );
        },
      ),
    );
  }
}
