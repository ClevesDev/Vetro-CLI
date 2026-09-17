import 'dart:async';

import '../failure/failure.dart';

/// A type-safe functional container representing either a success [data] of type [T]
/// or a failure [error] of type [E].
///
/// Implemented as a sealed class hierarchy to guarantee exhaustive pattern matching:
/// ```dart
/// switch (result) {
///   case Success(:final data):
///     print('Loaded: $data');
///   case FailureResult(:final error):
///     print('Error: ${error.message}');
/// }
/// ```
sealed class Result<T, E extends Failure> {
  const Result();

  /// Creates a [Success] containing [data].
  const factory Result.success(T data) = Success<T, E>;

  /// Creates a [FailureResult] containing [error].
  const factory Result.failure(E error) = FailureResult<T, E>;

  /// Whether this result is a [Success].
  bool get isSuccess => this is Success<T, E>;

  /// Whether this result is a [FailureResult].
  bool get isFailure => this is FailureResult<T, E>;

  /// Returns the successful data if this is a [Success], otherwise `null`.
  T? get dataOrNull => getOrNull();

  /// Returns the failure error if this is a [FailureResult], otherwise `null`.
  E? get errorOrNull => getErrorOrNull();

  /// Pattern-matches over this [Result], executing [success] if this is a
  /// [Success] or [failure] if this is a [FailureResult].
  R when<R>({
    required R Function(T data) success,
    required R Function(E error) failure,
  });

  /// Transforms the success value using [fn] if this is a [Success].
  /// Leaves [FailureResult] untouched.
  Result<R, E> map<R>(R Function(T data) fn);

  /// Transforms the failure value using [fn] if this is a [FailureResult].
  /// Leaves [Success] untouched.
  Result<T, R> mapError<R extends Failure>(R Function(E error) fn);

  /// Monadic bind: transforms the success value into another [Result] using [fn].
  Result<R, E> flatMap<R>(Result<R, E> Function(T data) fn);

  /// Folds the result into a single value of type [R], applying [onError]
  /// or [onSuccess].
  R fold<R>(R Function(E error) onError, R Function(T data) onSuccess);

  /// Returns the success data if available, or `null`.
  T? getOrNull();

  /// Returns the failure error if available, or `null`.
  E? getErrorOrNull();

  /// Returns the success data, or invokes [fallback] with the error.
  T getOrElse(T Function(E error) fallback);

  /// Returns the success data, or throws the underlying error.
  T getOrThrow();

  /// Executes synchronous [computation] and catches uncaught exceptions,
  /// returning a [Result].
  ///
  /// If [computation] throws a [Failure], it is returned directly as a [FailureResult].
  /// Any other unhandled exception is wrapped in an [UnexpectedFailure].
  static Result<T, Failure> guard<T>(T Function() computation) {
    try {
      return Success(computation());
    } on Failure catch (f) {
      return FailureResult(f);
    } catch (e, st) {
      return FailureResult(
        UnexpectedFailure(message: e.toString(), cause: e, stackTrace: st),
      );
    }
  }

  /// Executes asynchronous [computation] and catches uncaught exceptions,
  /// returning a [Future] of [Result].
  ///
  /// If [computation] throws a [Failure], it is returned directly as a [FailureResult].
  /// Any other unhandled exception is wrapped in an [UnexpectedFailure].
  static Future<Result<T, Failure>> guardAsync<T>(
    FutureOr<T> Function() computation,
  ) async {
    try {
      final value = await computation();
      return Success(value);
    } on Failure catch (f) {
      return FailureResult(f);
    } catch (e, st) {
      return FailureResult(
        UnexpectedFailure(message: e.toString(), cause: e, stackTrace: st),
      );
    }
  }
}

/// A successful [Result] containing [data] of type [T].
final class Success<T, E extends Failure> extends Result<T, E> {
  /// The successful payload.
  final T data;

  /// Creates a [Success] wrapping [data].
  const Success(this.data);

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(E error) failure,
  }) => success(data);

  @override
  Result<R, E> map<R>(R Function(T data) fn) => Success(fn(data));

  @override
  Result<T, R> mapError<R extends Failure>(R Function(E error) fn) =>
      Success(data);

  @override
  Result<R, E> flatMap<R>(Result<R, E> Function(T data) fn) => fn(data);

  @override
  R fold<R>(R Function(E error) onError, R Function(T data) onSuccess) =>
      onSuccess(data);

  @override
  T? getOrNull() => data;

  @override
  E? getErrorOrNull() => null;

  @override
  T getOrElse(T Function(E error) fallback) => data;

  @override
  T getOrThrow() => data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Success && data == other.data;

  @override
  int get hashCode => Object.hash(Success, data);

  @override
  String toString() => 'Success($data)';
}

/// A failed [Result] containing an [error] of type [E].
final class FailureResult<T, E extends Failure> extends Result<T, E> {
  /// The failure error payload.
  final E error;

  /// Creates a [FailureResult] wrapping [error].
  const FailureResult(this.error);

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(E error) failure,
  }) => failure(error);

  @override
  Result<R, E> map<R>(R Function(T data) fn) => FailureResult(error);

  @override
  Result<T, R> mapError<R extends Failure>(R Function(E error) fn) =>
      FailureResult(fn(error));

  @override
  Result<R, E> flatMap<R>(Result<R, E> Function(T data) fn) =>
      FailureResult(error);

  @override
  R fold<R>(R Function(E error) onError, R Function(T data) onSuccess) =>
      onError(error);

  @override
  T? getOrNull() => null;

  @override
  E? getErrorOrNull() => error;

  @override
  T getOrElse(T Function(E error) fallback) => fallback(error);

  @override
  T getOrThrow() {
    if (error.cause case final Object cause) {
      Error.throwWithStackTrace(cause, error.stackTrace ?? StackTrace.current);
    }
    throw error;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FailureResult && error == other.error;

  @override
  int get hashCode => Object.hash(FailureResult, error);

  @override
  String toString() => 'FailureResult($error)';
}
