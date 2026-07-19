import 'package:equatable/equatable.dart';

import '../../../timer/domain/entities/timer_preferences.dart';

/// Theme preference. Mirrors Flutter's `ThemeMode` without importing Flutter —
/// domain stays pure, and the mapping happens in `app.dart`.
enum AppThemeMode {
  system,
  light,
  dark;

  static AppThemeMode fromName(String? name) => switch (name) {
        'light' => AppThemeMode.light,
        'dark' => AppThemeMode.dark,
        _ => AppThemeMode.system,
      };

  String get label => switch (this) {
        AppThemeMode.system => 'System',
        AppThemeMode.light => 'Light',
        AppThemeMode.dark => 'Dark',
      };
}

/// Everything the Settings screen owns (docs → Navigation & IA § You/Settings).
///
/// Persisted locally — these are device preferences, not account data, so they
/// belong in `shared_preferences` rather than behind a round trip. A user who
/// picks dark mode on a plane should still have dark mode.
class AppSettings extends Equatable {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.timerStyle = TimerStyle.hold,
    this.inspectionEnabled = true,
    this.hapticsEnabled = true,
    this.soundEnabled = true,
  });

  final AppThemeMode themeMode;
  final TimerStyle timerStyle;
  final bool inspectionEnabled;
  final bool hapticsEnabled;
  final bool soundEnabled;

  /// The slice the timer cares about. Keeps [TimerBloc] independent of the
  /// settings feature — it takes preferences, not a settings repository.
  TimerPreferences get timerPreferences => TimerPreferences(
        style: timerStyle,
        inspectionEnabled: inspectionEnabled,
        hapticsEnabled: hapticsEnabled,
        soundEnabled: soundEnabled,
      );

  AppSettings copyWith({
    AppThemeMode? themeMode,
    TimerStyle? timerStyle,
    bool? inspectionEnabled,
    bool? hapticsEnabled,
    bool? soundEnabled,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        timerStyle: timerStyle ?? this.timerStyle,
        inspectionEnabled: inspectionEnabled ?? this.inspectionEnabled,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        soundEnabled: soundEnabled ?? this.soundEnabled,
      );

  @override
  List<Object?> get props => <Object?>[
        themeMode,
        timerStyle,
        inspectionEnabled,
        hapticsEnabled,
        soundEnabled,
      ];
}
