import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../timer/domain/entities/timer_preferences.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/profile_repository.dart';

/// Owns [AppSettings] for the whole app.
///
/// Provided above `MaterialApp` (see `app.dart`) because the theme is one of
/// these values — the app's appearance is settings state, not screen state.
/// The Timer screen reads [AppSettings.timerPreferences] off the same cubit.
///
/// Every change persists immediately. A settings screen with a save button is
/// a settings screen you can lose changes from.
class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit({
    required SettingsRepository repository,
    required AnalyticsService analytics,
  })  : _repository = repository,
        _analytics = analytics,
        super(const AppSettings());

  final SettingsRepository _repository;
  final AnalyticsService _analytics;

  /// Restores persisted settings. Called during bootstrap, before the first
  /// frame, so the app never flashes the wrong theme.
  Future<void> load() async {
    final AppSettings settings = await _repository.load();
    if (isClosed) return;
    emit(settings);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (mode == state.themeMode) return;
    _analytics.capture(
      'theme_changed',
      properties: <String, Object?>{'mode': mode.name},
    );
    await _update(state.copyWith(themeMode: mode));
  }

  Future<void> setTimerStyle(TimerStyle style) async {
    if (style == state.timerStyle) return;
    _analytics.capture(
      'timer_style_changed',
      properties: <String, Object?>{'style': style.name},
    );
    await _update(state.copyWith(timerStyle: style));
  }

  Future<void> setInspectionEnabled(bool enabled) =>
      _update(state.copyWith(inspectionEnabled: enabled));

  Future<void> setHapticsEnabled(bool enabled) =>
      _update(state.copyWith(hapticsEnabled: enabled));

  Future<void> setSoundEnabled(bool enabled) =>
      _update(state.copyWith(soundEnabled: enabled));

  Future<void> _update(AppSettings next) async {
    // Emit first: the toggle should move under the user's finger, not after a
    // disk write.
    emit(next);
    await _repository.save(next);
  }
}
