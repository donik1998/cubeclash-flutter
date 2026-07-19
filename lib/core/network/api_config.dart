/// Backend endpoint configuration.
///
/// Override the base URL at build time:
///   flutter run --dart-define=API_BASE_URL=https://api.cubeclash.app
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const String apiVersion = 'v1';

  /// REST base, e.g. `http://localhost:3000/v1` (contract: docs/API Design).
  static String get apiBase => '$baseUrl/$apiVersion';
}
