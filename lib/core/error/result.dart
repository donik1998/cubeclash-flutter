import 'failures.dart';

/// A value or a [Failure] — the return type of every repository method.
///
/// `failures.dart` states the rule: repositories return failures rather than
/// throwing, so presentation can handle them exhaustively. This sealed type is
/// what makes "exhaustively" real — a `switch` over [Ok] / [Err] is checked by
/// the compiler, so adding a new call site cannot silently forget the error
/// path.
///
/// Deliberately hand-rolled rather than pulling in dartz/fpdart: it is 40 lines
/// and Dart 3 sealed classes already give us the exhaustiveness that was the
/// only reason to take the dependency.
sealed class Result<T> {
  const Result();

  /// Runs [body], wrapping a thrown exception into [Err] via [onError].
  static Future<Result<T>> guard<T>(
    Future<T> Function() body, {
    required Failure Function(Object error, StackTrace stack) onError,
  }) async {
    try {
      return Ok<T>(await body());
    } catch (error, stack) {
      return Err<T>(onError(error, stack));
    }
  }

  bool get isOk => this is Ok<T>;

  /// The value, or `null` if this is an [Err].
  T? get valueOrNull => switch (this) {
        Ok<T>(:final T value) => value,
        Err<T>() => null,
      };

  /// The failure, or `null` if this is an [Ok].
  Failure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final Failure failure) => failure,
      };

  /// Transforms the success value, leaving a failure untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Ok<T>(:final T value) => Ok<R>(transform(value)),
        Err<T>(:final Failure failure) => Err<R>(failure),
      };
}

class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  String toString() => 'Err(${failure.message})';
}
