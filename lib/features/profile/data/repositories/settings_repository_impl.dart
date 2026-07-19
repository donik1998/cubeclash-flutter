import 'package:shared_preferences/shared_preferences.dart';

import '../../../timer/domain/entities/timer_preferences.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/profile_repository.dart';

/// [SettingsRepository] on `shared_preferences`.
///
/// Only implementation there is — settings are device preferences, not account
/// data, so there is no "fake vs real" split here and nothing to switch with
/// `kUseFakeData`. The whole point is that they work with no backend at all.
///
/// Reads are defensive: an unknown or corrupt value falls back to the default
/// rather than throwing, because a bad preference must never stop the app from
/// launching.
class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl();

  static const String _themeKey = 'settings.theme_mode';
  static const String _timerStyleKey = 'settings.timer_style';
  static const String _inspectionKey = 'settings.inspection_enabled';
  static const String _hapticsKey = 'settings.haptics_enabled';
  static const String _soundKey = 'settings.sound_enabled';

  @override
  Future<AppSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    const AppSettings defaults = AppSettings();

    return AppSettings(
      themeMode: AppThemeMode.fromName(prefs.getString(_themeKey)),
      timerStyle: prefs.getString(_timerStyleKey) == 'tap'
          ? TimerStyle.tap
          : TimerStyle.hold,
      inspectionEnabled:
          prefs.getBool(_inspectionKey) ?? defaults.inspectionEnabled,
      hapticsEnabled: prefs.getBool(_hapticsKey) ?? defaults.hapticsEnabled,
      soundEnabled: prefs.getBool(_soundKey) ?? defaults.soundEnabled,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await Future.wait<void>(<Future<void>>[
      prefs.setString(_themeKey, settings.themeMode.name),
      prefs.setString(_timerStyleKey, settings.timerStyle.name),
      prefs.setBool(_inspectionKey, settings.inspectionEnabled),
      prefs.setBool(_hapticsKey, settings.hapticsEnabled),
      prefs.setBool(_soundKey, settings.soundEnabled),
    ]);
  }
}
