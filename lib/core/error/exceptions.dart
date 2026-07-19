/// Data-layer exceptions. Thrown by data sources, mapped to `Failure`s in the
/// repository implementations.
class ServerException implements Exception {
  ServerException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;
}

class CacheException implements Exception {
  CacheException(this.message);

  final String message;
}

class NetworkException implements Exception {
  NetworkException(this.message);

  final String message;
}
