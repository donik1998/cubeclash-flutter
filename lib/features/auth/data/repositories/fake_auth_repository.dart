import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../domain/repositories/auth_repository.dart';

/// In-memory [AuthRepository] for the no-backend build.
///
/// Accepts any well-formed credentials and mints obviously fake tokens, but
/// still runs them through the real [TokenStore] so the router guard, the
/// bootstrap restore and the sign-out path are all genuinely exercised in the
/// demo rather than bypassed.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._tokens);

  final TokenStore _tokens;

  static const Duration _latency = Duration(milliseconds: 450);

  /// Registered emails, so a second sign-up with the same address is rejected
  /// the way the server would.
  final Set<String> _accounts = <String>{'you@example.com'};

  @override
  bool get hasSession => _tokens.hasSession;

  @override
  Future<Result<void>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await Future<void>.delayed(_latency);

    final String normalised = email.trim().toLowerCase();
    if (_accounts.contains(normalised)) {
      return const Err<void>(
        ServerFailure('An account with that email already exists.'),
      );
    }

    _accounts.add(normalised);
    await _issueTokens();
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_latency);

    // One rejected password so the error path is reachable in the demo.
    if (password == 'wrong') {
      return const Err<void>(
        AuthFailure('That email or password is incorrect.'),
      );
    }

    await _issueTokens();
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> completeProfile({
    required String displayName,
    String? country,
  }) async {
    await Future<void>.delayed(_latency);
    if (displayName.trim().isEmpty) {
      return const Err<void>(ServerFailure('Pick a display name.'));
    }
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> logout() async {
    await Future<void>.delayed(_latency);
    await _tokens.clear();
    return const Ok<void>(null);
  }

  Future<void> _issueTokens() => _tokens.setTokens(
        access: 'fake-access-token',
        refresh: 'fake-refresh-token',
      );
}
