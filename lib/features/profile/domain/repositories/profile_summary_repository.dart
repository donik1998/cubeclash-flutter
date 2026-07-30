import '../../../../core/error/result.dart';
import '../entities/profile_summary.dart';

/// The composite read-model behind the "You · Profile" screen.
///
/// **Additive** — this is separate from [ProfileRepository]'s thin `GET /me`
/// (which backs Friends/Settings and stays). `GET /me/profile` returns the six
/// values the profile screen needs in one round trip (spec §11.4).
///
/// Returns [Result] — never throws.
abstract class ProfileSummaryRepository {
  /// `GET /me/profile`. Identity is the request principal (JWT via the auth
  /// interceptor); no path/query identifies the user.
  ///
  /// [event] scopes the best-single and rank event (default `3x3`);
  /// [rankScope] scopes the rank (`global` | `country` | `friends`).
  Future<Result<ProfileSummary>> getProfileSummary({
    String event = '3x3',
    String rankScope = 'global',
  });
}
