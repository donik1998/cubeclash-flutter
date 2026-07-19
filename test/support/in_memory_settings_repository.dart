import 'package:cubeclash/features/profile/domain/entities/app_settings.dart';
import 'package:cubeclash/features/profile/domain/repositories/profile_repository.dart';

/// [SettingsRepository] backed by a field instead of `shared_preferences`.
///
/// The real implementation goes through a platform channel, which under
/// `flutter test` never answers — a settings write simply hangs. Any test that
/// touches settings must register this in the locator instead.
class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([this.stored = const AppSettings()]);

  AppSettings stored;

  /// How many times settings were written — lets tests assert that changes
  /// persist immediately rather than on some later save.
  int saveCount = 0;

  @override
  Future<AppSettings> load() async => stored;

  @override
  Future<void> save(AppSettings settings) async {
    stored = settings;
    saveCount++;
  }
}
