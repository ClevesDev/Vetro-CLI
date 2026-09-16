# Changelog

All notable changes to the `vetro_core` package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-09-16

### Added
- **`Result<T, E extends Failure>`**: Pure Dart 3 functional container using sealed classes (`Success<T, E>` and `FailureResult<T, E>`).
- Comprehensive combinators: `when`, `map`, `mapError`, `flatMap`, `fold`, `getOrNull`, `getErrorOrNull`, `getOrElse`, `getOrThrow`.
- Computation safety guards: `Result.guard` and `Result.guardAsync` for intercepting unhandled exceptions.
- **`Failure` base contract**: Extensible root class for all application and domain failures.
- **`StandardFailure` sealed hierarchy**: Built-in infrastructure failures (`NetworkFailure`, `ServerFailure`, `ValidationFailure`, `NotFoundFailure`, `UnexpectedFailure`).
- **`CompositeErrorMapper`**: Supervisor delegation registry for decoupled UI error translation.
- **`FeatureErrorMapper` & `BaseFeatureErrorMapper<F>`**: Feature-isolated contracts mapping failures without monolithic switch statements.
- **`StandardErrorMapper`**: Default baseline translation for all standard infrastructure failures.
- **`UserMessage`**: Sanitized, UI-ready value object with title, message, error codes, and action labels.
- Comprehensive unit test suite with 100% coverage on functional and presentation primitives.
