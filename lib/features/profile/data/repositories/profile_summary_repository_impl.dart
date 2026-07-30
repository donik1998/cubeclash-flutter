import 'package:dio/dio.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_failures.dart';
import '../../domain/entities/profile_summary.dart';
import '../../domain/repositories/profile_summary_repository.dart';
import '../models/profile_summary_dto.dart';

/// The real [ProfileSummaryRepository], over [DioClient].
///
/// Auth is the shared `AuthInterceptor` on [DioClient] (JWT) — no `X-User-Id`
/// header; the spec's header note is backend-side.
class ProfileSummaryRepositoryImpl implements ProfileSummaryRepository {
  ProfileSummaryRepositoryImpl(this._client);

  final DioClient _client;

  @override
  Future<Result<ProfileSummary>> getProfileSummary({
    String event = '3x3',
    String rankScope = 'global',
  }) =>
      Result.guard<ProfileSummary>(
        () async {
          final Response<dynamic> response = await _client.dio.get<dynamic>(
            '/me/profile',
            queryParameters: <String, dynamic>{
              'event': event,
              'rank_scope': rankScope,
            },
          );

          // The composite is returned unwrapped (its top level is the object).
          // `unwrap` tolerates a `{ profile: … }` envelope too, so a server
          // that wraps it does not break the client.
          final ProfileSummaryDto dto = ProfileSummaryDto.fromJson(
            unwrap(response.data, 'profile'),
          );
          final ProfileSummary? summary = ProfileSummaryMapper.toDomain(dto);

          // A null here means the record lacked load-bearing identity
          // (`id`/`display_name`) — surface it as a failure rather than
          // fabricating a user.
          if (summary == null) {
            throw const _UnusableProfile();
          }
          return summary;
        },
        onError: (Object error, StackTrace stack) => error is _UnusableProfile
            ? const ServerFailure('That profile could not be read.')
            : dioFailure(error, stack),
      );
}

/// Thrown internally when the mapper drops the record for missing identity, so
/// `Result.guard`'s `onError` can convert it to a [ServerFailure].
class _UnusableProfile implements Exception {
  const _UnusableProfile();
}
