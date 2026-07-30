import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A [HttpClientAdapter] that serves scripted responses so a **real repository
/// over a real Dio** can be tested against captured server bytes without a
/// network — the parse path (interceptor → DTO → mapper) runs exactly as it
/// would live.
class FixtureAdapter implements HttpClientAdapter {
  FixtureAdapter(this.handler);

  /// Returns the response to serve for a given request.
  final ResponseBody Function(RequestOptions options) handler;

  /// Every request seen, in order — assert on method/path/body.
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A JSON [ResponseBody] with the given status.
ResponseBody jsonResponse(Object body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

/// A 204 No Content response (DELETE /solves/:id, POST /auth/logout).
ResponseBody noContent() => ResponseBody.fromString(
      '',
      204,
      headers: <String, List<String>>{},
    );
