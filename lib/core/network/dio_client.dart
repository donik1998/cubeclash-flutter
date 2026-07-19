import 'package:dio/dio.dart';

import 'api_config.dart';
import 'auth_interceptor.dart';

/// Configured Dio instance shared by all remote data sources.
class DioClient {
  DioClient(this._tokens) {
    // A second, un-intercepted client for token refresh and for replaying the
    // original request. Refreshing through the intercepted instance would
    // recurse on its own 401.
    final Dio refreshClient = Dio(_baseOptions);

    _dio = Dio(_baseOptions)
      ..interceptors.add(AuthInterceptor(_tokens, refreshClient));
  }

  static BaseOptions get _baseOptions => BaseOptions(
        baseUrl: ApiConfig.apiBase,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
      );

  final TokenStore _tokens;
  late final Dio _dio;

  Dio get dio => _dio;
}
