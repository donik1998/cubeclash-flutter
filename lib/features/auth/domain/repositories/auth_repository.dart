import '../../../../core/error/result.dart';

/// Authentication — `POST /auth/*` (docs → API Design § Auth).
///
/// Every method that succeeds has already stored the returned tokens; callers
/// never handle raw credentials. `Result<void>` rather than `Result<Tokens>`
/// for exactly that reason — a token that reaches presentation is a token that
/// can be logged.
abstract class AuthRepository {
  /// `POST /auth/register { email, password, display_name }`
  Future<Result<void>> register({
    required String email,
    required String password,
    required String displayName,
  });

  /// `POST /auth/login { email, password }`
  Future<Result<void>> login({
    required String email,
    required String password,
  });

  /// `PATCH /me { display_name?, country? }` — the profile-setup step.
  Future<Result<void>> completeProfile({
    required String displayName,
    String? country,
  });

  /// `POST /auth/logout`, then clears local tokens regardless of the response.
  Future<Result<void>> logout();

  /// Whether a session was restored at launch.
  bool get hasSession;
}
