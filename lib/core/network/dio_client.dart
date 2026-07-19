import 'package:dio/dio.dart';

import 'api_config.dart';
import 'auth_interceptor.dart';

/// Configured Dio instance shared by all remote data sources.
class DioClient {
  DioClient(this._tokens) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.apiBase,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
      ),
    )..interceptors.add(AuthInterceptor(_tokens));
  }

  final TokenStore _tokens;
  late final Dio _dio;

  Dio get dio => _dio;
}
