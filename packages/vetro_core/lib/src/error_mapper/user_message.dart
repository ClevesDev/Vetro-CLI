/// User-facing error presentation model.
library;

/// Represents a sanitized, human-friendly message suitable for presentation
/// in the user interface (e.g. snackbars, dialogs, banner alerts, or form states).
final class UserMessage {
  /// Short heading or summary of the problem (e.g. `'No Internet Connection'`).
  final String title;

  /// Detailed, user-friendly explanation or instructions on how to resolve the issue.
  final String message;

  /// Optional machine-readable or support reference code (e.g. `'ERR_AUTH_EXPIRED'`).
  final String? code;

  /// Optional label for a primary call-to-action button (e.g. `'Retry'`, `'Log In'`).
  final String? actionLabel;

  /// Optional contextual metadata or parameters for custom rendering.
  final Map<String, Object?>? metadata;

  /// Creates a [UserMessage] instance.
  const UserMessage({
    required this.title,
    required this.message,
    this.code,
    this.actionLabel,
    this.metadata,
  });

  /// Creates a standard generic error message fallback.
  const UserMessage.generic({
    this.title = 'Something went wrong',
    this.message = 'An unexpected error occurred. Please try again later.',
    this.code,
    this.actionLabel = 'Dismiss',
    this.metadata,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UserMessage) return false;
    if (runtimeType != other.runtimeType) return false;
    if (title != other.title ||
        message != other.message ||
        code != other.code ||
        actionLabel != other.actionLabel) {
      return false;
    }
    if (metadata == null && other.metadata == null) return true;
    if (metadata == null || other.metadata == null) return false;
    if (metadata!.length != other.metadata!.length) return false;
    for (final entry in metadata!.entries) {
      if (other.metadata![entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var metaHash = 0;
    if (metadata case final meta?) {
      for (final entry in meta.entries) {
        metaHash ^= Object.hash(entry.key, entry.value);
      }
    }
    return Object.hash(title, message, code, actionLabel, metaHash);
  }

  @override
  String toString() =>
      'UserMessage(title: $title, message: $message, code: $code, actionLabel: $actionLabel)';
}
