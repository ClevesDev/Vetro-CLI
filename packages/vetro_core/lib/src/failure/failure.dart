/// Core failure abstractions and standard failure types for error handling.
library;

/// Base contract for all application, domain, and infrastructure failures.
///
/// Features can define domain-specific failure hierarchies by extending
/// [Failure]:
/// ```dart
/// sealed class AuthFailure extends Failure {
///   const AuthFailure({required super.message, super.code, super.cause});
/// }
///
/// final class InvalidCredentialsFailure extends AuthFailure {
///   const InvalidCredentialsFailure()
///       : super(message: 'Invalid email or password.');
/// }
/// ```
abstract class Failure {
  /// Human-readable diagnostic description of the failure.
  final String message;

  /// Optional machine-readable error code (e.g. `'ERR_NETWORK_TIMEOUT'`).
  final String? code;

  /// Optional underlying exception, error, or cause object.
  final Object? cause;

  /// Optional stack trace captured at the failure site.
  final StackTrace? stackTrace;

  /// Creates a new [Failure] instance.
  const Failure({
    required this.message,
    this.code,
    this.cause,
    this.stackTrace,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code &&
          cause == other.cause;

  @override
  int get hashCode => Object.hash(runtimeType, message, code, cause);

  @override
  String toString() => '$runtimeType(message: $message, code: $code)';
}

/// Built-in standard failure types for common infrastructure and runtime scenarios.
///
/// All standard failures form a sealed hierarchy, enabling exhaustive
/// pattern matching when working directly with infrastructure errors:
/// ```dart
/// switch (failure) {
///   case NetworkFailure(:final isTimeout) => ...
///   case ServerFailure(:final statusCode) => ...
///   case ValidationFailure(:final fieldErrors) => ...
///   case NotFoundFailure(:final resourceType) => ...
///   case UnexpectedFailure() => ...
/// }
/// ```
sealed class StandardFailure extends Failure {
  /// Creates a standard failure.
  const StandardFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

/// Failure representing network connectivity, transport, or timeout issues.
final class NetworkFailure extends StandardFailure {
  /// Whether the network failure was caused by a request timeout.
  final bool isTimeout;

  /// Creates a [NetworkFailure].
  const NetworkFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
    this.isTimeout = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is NetworkFailure && isTimeout == other.isTimeout;

  @override
  int get hashCode => Object.hash(super.hashCode, isTimeout);

  @override
  String toString() =>
      'NetworkFailure(message: $message, code: $code, isTimeout: $isTimeout)';
}

/// Failure representing server-side or remote API errors.
final class ServerFailure extends StandardFailure {
  /// Optional HTTP status code associated with the server response (e.g. 500, 502).
  final int? statusCode;

  /// Creates a [ServerFailure].
  const ServerFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
    this.statusCode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ServerFailure &&
          statusCode == other.statusCode;

  @override
  int get hashCode => Object.hash(super.hashCode, statusCode);

  @override
  String toString() =>
      'ServerFailure(message: $message, code: $code, statusCode: $statusCode)';
}

/// Failure representing client validation or schema constraint violations.
final class ValidationFailure extends StandardFailure {
  /// Map of field names to their specific validation error messages.
  final Map<String, String> fieldErrors;

  /// Creates a [ValidationFailure].
  const ValidationFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
    this.fieldErrors = const <String, String>{},
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (super != other || other is! ValidationFailure) return false;
    if (fieldErrors.length != other.fieldErrors.length) return false;
    for (final entry in fieldErrors.entries) {
      if (other.fieldErrors[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var entriesHash = 0;
    for (final entry in fieldErrors.entries) {
      entriesHash ^= Object.hash(entry.key, entry.value);
    }
    return Object.hash(super.hashCode, entriesHash);
  }

  @override
  String toString() =>
      'ValidationFailure(message: $message, code: $code, fieldErrors: $fieldErrors)';
}

/// Failure representing an entity or resource that could not be located.
final class NotFoundFailure extends StandardFailure {
  /// Optional type or name of the resource that was not found.
  final String? resourceType;

  /// Optional identifier of the resource that was not found.
  final String? resourceId;

  /// Creates a [NotFoundFailure].
  const NotFoundFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
    this.resourceType,
    this.resourceId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is NotFoundFailure &&
          resourceType == other.resourceType &&
          resourceId == other.resourceId;

  @override
  int get hashCode => Object.hash(super.hashCode, resourceType, resourceId);

  @override
  String toString() =>
      'NotFoundFailure(message: $message, code: $code, resourceType: $resourceType, resourceId: $resourceId)';
}

/// Failure representing an unforeseen runtime bug, exception, or state error.
final class UnexpectedFailure extends StandardFailure {
  /// Creates an [UnexpectedFailure].
  const UnexpectedFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() =>
      'UnexpectedFailure(message: $message, code: $code, cause: $cause)';
}
