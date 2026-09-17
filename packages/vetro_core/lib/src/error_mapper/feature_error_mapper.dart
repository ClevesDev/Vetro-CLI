import '../failure/failure.dart';
import 'user_message.dart';

/// Contract for feature-specific error translation.
///
/// Implement this interface to translate domain or feature failures
/// into user-facing [UserMessage] instances without centralizing error logic
/// in monolithic switch statements:
/// ```dart
/// final class AuthErrorMapper implements FeatureErrorMapper {
///   @override
///   bool canHandle(Failure failure) => failure is AuthFailure;
///
///   @override
///   UserMessage map(Failure failure) {
///     return switch (failure as AuthFailure) {
///       InvalidCredentialsFailure() => const UserMessage(
///           title: 'Invalid Credentials',
///           message: 'The username or password you entered is incorrect.',
///         ),
///       SessionExpiredFailure() => const UserMessage(
///           title: 'Session Expired',
///           message: 'Your session has timed out. Please sign in again.',
///           actionLabel: 'Sign In',
///         ),
///     };
///   }
/// }
/// ```
abstract interface class FeatureErrorMapper {
  /// Whether this mapper knows how to translate [failure].
  bool canHandle(Failure failure);

  /// Translates [failure] into a user-facing [UserMessage].
  ///
  /// Callers should verify [canHandle] before calling [map].
  UserMessage map(Failure failure);
}

/// A type-safe convenience base class for feature mappers handling a specific
/// subtype [F] of [Failure].
///
/// Automatically handles type checks in [canHandle] and ensures [mapFailure]
/// receives a strictly-typed instance of [F]:
/// ```dart
/// final class CartErrorMapper extends BaseFeatureErrorMapper<CartFailure> {
///   const CartErrorMapper();
///
///   @override
///   UserMessage mapFailure(CartFailure failure) => switch (failure) {
///     ItemOutOfStockFailure(:final itemName) => UserMessage(
///         title: 'Out of Stock',
///         message: 'Item "$itemName" is currently out of stock.',
///       ),
///   };
/// }
/// ```
abstract class BaseFeatureErrorMapper<F extends Failure>
    implements FeatureErrorMapper {
  /// Creates a [BaseFeatureErrorMapper].
  const BaseFeatureErrorMapper();

  @override
  bool canHandle(Failure failure) => failure is F;

  @override
  UserMessage map(Failure failure) {
    if (failure is! F) {
      throw ArgumentError.value(
        failure,
        'failure',
        'Expected a failure of type $F, but received ${failure.runtimeType}.',
      );
    }
    return mapFailure(failure);
  }

  /// Translates the strictly-typed [failure] into a user-facing [UserMessage].
  UserMessage mapFailure(F failure);
}
