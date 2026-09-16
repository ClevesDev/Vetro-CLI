import '../failure/failure.dart';
import 'feature_error_mapper.dart';
import 'standard_error_mapper.dart';
import 'user_message.dart';

/// Central supervisor and delegation registry for error presentation.
///
/// Dispatches errors to registered [FeatureErrorMapper] instances in priority
/// order, preventing monolithic presentation switch statements while providing
/// a unified entry point for presentation layers (controllers, blocs, UI alerts).
///
/// ```dart
/// final mapper = CompositeErrorMapper()
///   ..register(AuthErrorMapper())
///   ..register(BillingErrorMapper());
///
/// final userMessage = mapper.map(someFailure);
/// ScaffoldMessenger.of(context).showSnackBar(
///   SnackBar(content: Text(userMessage.message)),
/// );
/// ```
final class CompositeErrorMapper {
  final List<FeatureErrorMapper> _mappers = [];
  final UserMessage Function(Object error)? _customFallback;

  /// Creates a [CompositeErrorMapper].
  ///
  /// If [includeStandardMapper] is `true` (default), [StandardErrorMapper] is
  /// registered as the baseline fallback handler for built-in [StandardFailure] types.
  ///
  /// An optional [fallbackHandler] can be provided to customize the final
  /// fallback message when no registered mapper matches the error.
  CompositeErrorMapper({
    bool includeStandardMapper = true,
    Iterable<FeatureErrorMapper>? mappers,
    UserMessage Function(Object error)? fallbackHandler,
  }) : _customFallback = fallbackHandler {
    if (mappers != null) {
      _mappers.addAll(mappers);
    }
    if (includeStandardMapper) {
      _mappers.add(const StandardErrorMapper());
    }
  }

  /// Unmodifiable view of all currently registered feature mappers.
  List<FeatureErrorMapper> get registeredMappers => List.unmodifiable(_mappers);

  /// Registers a [FeatureErrorMapper] into the delegation chain.
  ///
  /// By default, new feature mappers take precedence over the baseline
  /// [StandardErrorMapper]. If [highPriority] is `true`, the mapper is inserted
  /// at the very beginning of the evaluation chain.
  void register(FeatureErrorMapper mapper, {bool highPriority = false}) {
    if (highPriority || _mappers.isEmpty) {
      _mappers.insert(0, mapper);
      return;
    }

    // If the last mapper is StandardErrorMapper, insert just before it
    // so feature mappers always take precedence over default infrastructure.
    if (_mappers.last is StandardErrorMapper) {
      _mappers.insert(_mappers.length - 1, mapper);
    } else {
      _mappers.add(mapper);
    }
  }

  /// Registers multiple [FeatureErrorMapper] instances.
  void registerAll(Iterable<FeatureErrorMapper> mappers) {
    for (final mapper in mappers) {
      register(mapper);
    }
  }

  /// Translates [error] into a sanitized, user-facing [UserMessage].
  ///
  /// If [error] is a [Failure], each registered mapper is queried in priority
  /// order via [FeatureErrorMapper.canHandle]. The first matching mapper translates
  /// the failure.
  ///
  /// If no registered mapper can handle the failure, or if [error] is an unhandled
  /// raw runtime exception, the error falls back to the configured fallback
  /// handler or a standard generic [UserMessage].
  UserMessage map(Object error) {
    if (error is Failure) {
      for (final mapper in _mappers) {
        if (mapper.canHandle(error)) {
          return mapper.map(error);
        }
      }
    }

    if (_customFallback != null) {
      return _customFallback(error);
    }

    if (error is Failure) {
      return UserMessage(
        title: 'Operation Failed',
        message: error.message.isNotEmpty
            ? error.message
            : 'An unhandled application error occurred.',
        code: error.code,
        actionLabel: 'Dismiss',
      );
    }

    return UserMessage.generic(metadata: {'cause': error.toString()});
  }
}
