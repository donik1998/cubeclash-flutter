import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// An access + refresh token pair.
class TokenPair {
  const TokenPair({required this.access, required this.refresh});

  final String access;
  final String refresh;
}

/// Where tokens are kept between launches.
///
/// An interface so tests (and the fake-data build) can avoid the platform
/// channel — `flutter_secure_storage` talks to the Keychain / Keystore, which
/// under `flutter test` never answers.
abstract class TokenStorage {
  Future<TokenPair?> read();

  Future<void> write(TokenPair tokens);

  Future<void> clear();
}

/// Keychain (iOS) / EncryptedSharedPreferences (Android).
///
/// Tokens must survive a relaunch — otherwise every cold start is a forced
/// sign-in — and they must not sit in plain storage, because a refresh token
/// is a long-lived credential (~30 days, per docs → API Design).
class SecureTokenStorage implements TokenStorage {
  // Defaults are correct on both platforms: Keychain on iOS, and on Android
  // the plugin now applies its own ciphers (the Jetpack Security path is
  // deprecated), so no AndroidOptions override is needed.
  const SecureTokenStorage([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const String _accessKey = 'auth.access_token';
  static const String _refreshKey = 'auth.refresh_token';

  @override
  Future<TokenPair?> read() async {
    final String? access = await _storage.read(key: _accessKey);
    final String? refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    return TokenPair(access: access, refresh: refresh);
  }

  @override
  Future<void> write(TokenPair tokens) async {
    await _storage.write(key: _accessKey, value: tokens.access);
    await _storage.write(key: _refreshKey, value: tokens.refresh);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// Non-persistent storage. Used by tests and by the `kUseFakeData` build, where
/// there is no real session to protect.
class InMemoryTokenStorage implements TokenStorage {
  TokenPair? _tokens;

  @override
  Future<TokenPair?> read() async => _tokens;

  @override
  Future<void> write(TokenPair tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
