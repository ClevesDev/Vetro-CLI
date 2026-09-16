import '../failure/failure.dart';
import 'feature_error_mapper.dart';
import 'user_message.dart';

/// Default error mapper providing clean, production-ready user messages
/// for all built-in [StandardFailure] types.
///
/// Typically used as the baseline fallback in a [CompositeErrorMapper].
final class StandardErrorMapper implements FeatureErrorMapper {
  /// Creates a [StandardErrorMapper].
  const StandardErrorMapper();

  @override
  bool canHandle(Failure failure) => failure is StandardFailure;

  @override
  UserMessage map(Failure failure) {
    if (failure is! StandardFailure) {
      throw ArgumentError.value(
        failure,
        'failure',
        'StandardErrorMapper only supports StandardFailure instances.',
      );
    }

    return switch (failure) {
      NetworkFailure(:final isTimeout, :final code) => UserMessage(
        title: isTimeout ? 'Connection Timeout' : 'No Internet Connection',
        message: isTimeout
            ? 'The server took too long to respond. Please check your connection and try again.'
            : 'Unable to reach the server. Please check your internet connection.',
        code: code,
        actionLabel: 'Retry',
      ),
      ServerFailure(:final statusCode, :final code) => UserMessage(
        title: 'Server Error',
        message: statusCode != null
            ? 'A remote server error occurred (Status $statusCode). Please try again shortly.'
            : 'A remote server error occurred. Please try again shortly.',
        code: code,
        actionLabel: 'Retry',
      ),
      ValidationFailure(:final message, :final fieldErrors, :final code) =>
        UserMessage(
          title: 'Validation Error',
          message: message,
          code: code,
          metadata: fieldErrors.isNotEmpty ? fieldErrors : null,
        ),
      NotFoundFailure(:final message, :final resourceType, :final code) =>
        UserMessage(
          title: resourceType != null ? '$resourceType Not Found' : 'Not Found',
          message: message,
          code: code,
        ),
      UnexpectedFailure(:final code) => UserMessage(
        title: 'Unexpected Error',
        message:
            'An unexpected problem occurred. Please try again or contact support.',
        code: code,
        actionLabel: 'Dismiss',
      ),
    };
  }
}
