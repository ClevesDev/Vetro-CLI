# vetro_core

Lightweight, zero-codegen architectural runtime primitives for Flutter and Dart.

Part of the [Vetro](https://github.com/ClevesDev/Vetro-CLI) architecture suite.

---

## Features

- **`Result<T, E extends Failure>`**: Type-safe functional return container powered by Dart 3 sealed classes and exhaustive pattern matching. Eliminates uncaught runtime exceptions across business logic.
- **`Failure` Hierarchy**: Extensible base contract for domain failures (`Failure`) with built-in standard infrastructure models (`StandardFailure`: `NetworkFailure`, `ServerFailure`, `ValidationFailure`, `NotFoundFailure`, `UnexpectedFailure`).
- **Ergonomic Functional Combinators**: `when`, `map`, `mapError`, `flatMap` (monadic bind), `fold`, `getOrElse`, `getOrNull`, and `getOrThrow`.
- **Safe Computation Guards**: `Result.guard(...)` and `Result.guardAsync(...)` to safely intercept uncaught runtime exceptions and map them to deterministic failures.
- **Value Equality & Fast Hashing**: Built-in order-independent equality for unit tests and state management caches.
- **Zero-Codegen & Pure Dart**: 100% pure Dart 3 (`sdk: ^3.11.0` / Dart 3.12+). Zero dependencies on `build_runner`, `freezed`, or code generation tools.

---

## Installation

Add `vetro_core` to your `pubspec.yaml`:

```yaml
dependencies:
  vetro_core: ^0.1.0
```

---

## Usage Guide

### 1. Functional Return Type (`Result<T, E>`)

Replace throwing exceptions with explicit, compiler-checked results:

```dart
import 'package:vetro_core/vetro_core.dart';

Result<User, Failure> authenticateUser(String email, String password) {
  if (email.isEmpty) {
    return const FailureResult(
      ValidationFailure(
        message: 'Email cannot be empty',
        fieldErrors: {'email': 'Required field'},
      ),
    );
  }

  return const Success(User(id: 'usr_1', email: 'user@example.com'));
}
```

### 2. Exhaustive Dart 3 Pattern Matching

Because `Result` is a sealed class, the Dart compiler enforces exhaustive handling of all states:

```dart
final result = authenticateUser('user@example.com', 'secret');

// Pattern matching via switch expression
final uiMessage = switch (result) {
  Success(:final data) => 'Welcome back, ${data.email}!',
  FailureResult(:final error) => 'Login failed: ${error.message}',
};
```

Or via the functional `when` method:

```dart
result.when(
  success: (user) => print('Logged in as ${user.email}'),
  failure: (error) => print('Error: ${error.message}'),
);
```

### 3. Transforming and Chaining Results (`map` and `flatMap`)

```dart
// Transform successful data without unwrapping
final Result<String, Failure> tokenResult = result.map((user) => user.id);

// Monadic chaining: execute dependent steps only if preceding steps succeeded
Result<Profile, Failure> loadProfile(User user) => ...;

final Result<Profile, Failure> profileResult = result.flatMap(loadProfile);
```

### 4. Safe Computation Guards (`Result.guard`)

Safely run legacy or third-party code that might throw exceptions:

```dart
// Synchronous guard
final Result<int, Failure> parsed = Result.guard(() => int.parse('42'));

// Asynchronous guard
final Result<String, Failure> payload = await Result.guardAsync(() async {
  return await remoteHttpClient.get('/resource');
});
```

Any caught `Failure` is preserved, while unexpected runtime errors are wrapped in `UnexpectedFailure` with stack trace preservation.

### 5. Standard Failures

`vetro_core` provides built-in failure models for common scenarios:

- **`NetworkFailure`**: Connectivity issues, socket drops, DNS failures, or timeouts (`isTimeout: true`).
- **`ServerFailure`**: Remote HTTP/API errors with optional `statusCode` (e.g. 500, 503).
- **`ValidationFailure`**: Input constraint violations with `fieldErrors` map.
- **`NotFoundFailure`**: Missing entities with `resourceType` and `resourceId`.
- **`UnexpectedFailure`**: Unforeseen runtime crashes capturing underlying `cause` and `stackTrace`.

```dart
switch (failure) {
  case NetworkFailure(:final isTimeout) =>
    isTimeout ? 'Request timed out' : 'Check your connection',
  case ServerFailure(:final statusCode) => 'Server error ($statusCode)',
  case ValidationFailure(:final fieldErrors) => 'Check form fields: $fieldErrors',
  case NotFoundFailure(:final resourceType) => '$resourceType not found',
  case UnexpectedFailure(:final cause) => 'Internal application error',
}
```

### 6. Custom Domain Failures

Define feature-specific sealed failure hierarchies by extending `Failure`:

```dart
sealed class CheckoutFailure extends Failure {
  const CheckoutFailure({required super.message, super.code, super.cause});
}

final class OutOfStockFailure extends CheckoutFailure {
  final String itemId;
  const OutOfStockFailure(this.itemId)
      : super(message: 'Item $itemId is out of stock', code: 'OUT_OF_STOCK');
}

final class PaymentDeclinedFailure extends CheckoutFailure {
  const PaymentDeclinedFailure(String reason)
      : super(message: 'Payment declined: $reason', code: 'PAYMENT_DECLINED');
}
```

### 7. Modular Error Presentation Architecture (`CompositeErrorMapper`)

Prevent massive 1000-line presentation switch statements by letting each feature own its error mapping while providing a single entry point for UI layers:

```dart
import 'package:vetro_core/vetro_core.dart';

// 1. Feature defines its local mapper
final class CheckoutErrorMapper extends BaseFeatureErrorMapper<CheckoutFailure> {
  const CheckoutErrorMapper();

  @override
  UserMessage mapFailure(CheckoutFailure failure) => switch (failure) {
    OutOfStockFailure(:final itemId) => UserMessage(
        title: 'Item Unavailable',
        message: 'Item $itemId is no longer in stock.',
        code: 'CHECKOUT_OUT_OF_STOCK',
      ),
    PaymentDeclinedFailure(:final declineReason) => UserMessage(
        title: 'Payment Failed',
        message: declineReason,
        code: 'CHECKOUT_PAYMENT_DECLINED',
        actionLabel: 'Update Payment Method',
      ),
  };
}

// 2. Register mappers centrally or inject via DI
final errorMapper = CompositeErrorMapper()
  ..register(const CheckoutErrorMapper());

// 3. Presentation layer converts ANY failure or exception into UI-ready messages
void onCheckoutError(Object error) {
  final UserMessage message = errorMapper.map(error);
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${message.title}: ${message.message}'),
      action: message.actionLabel != null
          ? SnackBarAction(label: message.actionLabel!, onPressed: () {})
          : null,
    ),
  );
}
```

---

## License

MIT © 2026 Dimas Rafael López Cleves
