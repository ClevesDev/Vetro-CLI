# vetro_core

Lightweight, zero-codegen architectural runtime primitives for Flutter and Dart.

Part of the [Vetro](https://github.com/ClevesDev/Vetro-CLI) architecture suite.

## Features

- **`Result<T, E>`**: Type-safe functional return type with Dart 3 pattern matching and sealed classes. Zero exceptions in business logic.
- **`Failure`**: Extensible domain failure hierarchy (`NetworkFailure`, `ServerFailure`, `ValidationFailure`, etc.).
- **`CompositeErrorMapper`**: Modular supervisor/delegation architecture for UI error presentation. Each feature owns its local `FeatureErrorMapper` without monolithic switch statements.
- **Zero-Codegen**: 100% pure Dart 3. No `build_runner`, no code generation latency, instant compilation.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  vetro_core: ^0.1.0
```

## Quick Start

### 1. Functional Result Type

```dart
import 'package:vetro_core/vetro_core.dart';

Result<User, Failure> fetchUser(String id) {
  if (id.isEmpty) {
    return const FailureResult(ValidationFailure('User ID cannot be empty'));
  }
  return const Success(User(id: '123', name: 'Alice'));
}

void handleResult(Result<User, Failure> result) {
  switch (result) {
    case Success(:final data):
      print('User: ${data.name}');
    case FailureResult(:final error):
      print('Failed: ${error.message}');
  }
}
```

### 2. Composite Error Mapper Pattern

```dart
final mapper = CompositeErrorMapper()
  ..register(AuthErrorMapper())
  ..register(BillingErrorMapper());

final message = mapper.map(someFailure);
print('${message.title}: ${message.message}');
```

## License

MIT © 2026 Dimas Rafael López Cleves
