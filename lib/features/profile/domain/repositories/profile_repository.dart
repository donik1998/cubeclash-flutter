import '../../../../core/error/result.dart';
import '../entities/app_settings.dart';
import '../entities/badge.dart';
import '../entities/user_profile.dart';

/// Account and social data.
///
/// Endpoints (docs → API Design): `GET /me`, `PATCH /me`, and the friends
/// group — `GET /friends`, `POST /friends/invite`, `POST /friends/:id/accept`.
///
/// Note the vault lists the friends endpoints under **roadmap**, not MVP, while
/// Concept & Scope puts "social (lean) — profiles, friends/invite" *in* scope.
/// Built here because the Friends screen is in the MVP screen list; if the
/// server ships without them, the fake keeps the screen working and the real
/// impl returns a clean failure rather than crashing.
abstract class ProfileRepository {
  Future<Result<UserProfile>> getMe();

  Future<Result<UserProfile>> updateMe({String? displayName, String? country});

  Future<Result<List<Friend>>> getFriends();

  /// The signed-in user's achievements, earned and locked. Server-owned in
  /// production (`GET /me/badges`).
  Future<Result<List<Badge>>> getBadges();

  /// Invite by display name or email — the doc doesn't say which, so the impl
  /// sends whatever the user typed under `query`.
  Future<Result<void>> inviteFriend(String query);

  Future<Result<void>> acceptFriend(String userId);

  /// Ends the session. Clears local tokens whatever the server says — a logout
  /// that fails to log you out is worse than one that fails loudly.
  Future<Result<void>> logout();
}

/// Local, device-scoped preferences. Deliberately separate from
/// [ProfileRepository]: settings are not account data and must work offline.
abstract class SettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}
