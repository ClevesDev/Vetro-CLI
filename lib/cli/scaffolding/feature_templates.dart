/// String templates for Vetro feature scaffolding.
library;

import 'feature_generator.dart';

/// Provides raw string templates for generated feature files.
abstract final class FeatureTemplates {
  /// Generates the domain failure hierarchy.
  static String failure(String pascalName) {
    return '''
/// Domain failures for the $pascalName feature.
library;

import 'package:vetro_core/vetro_core.dart';

/// Base sealed failure hierarchy for $pascalName operations.
sealed class ${pascalName}Failure extends Failure {
  const ${pascalName}Failure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

/// Emitted when a requested $pascalName entity or resource is not found.
final class ${pascalName}NotFoundFailure extends ${pascalName}Failure {
  const ${pascalName}NotFoundFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

/// Emitted when infrastructure, network, or server communication fails.
final class ${pascalName}NetworkFailure extends ${pascalName}Failure {
  const ${pascalName}NetworkFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

/// Emitted when validation fails for $pascalName input data.
final class ${pascalName}ValidationFailure extends ${pascalName}Failure {
  const ${pascalName}ValidationFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

/// Fallback failure for unexpected or unhandled exceptions in $pascalName.
final class ${pascalName}UnexpectedFailure extends ${pascalName}Failure {
  const ${pascalName}UnexpectedFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}
''';
  }

  /// Generates the domain repository interface and default implementation.
  static String repository(String pascalName, String snakeName) {
    return '''
/// Repository contracts and implementation for $pascalName.
library;

import 'package:vetro_core/vetro_core.dart';
import '${snakeName}_failure.dart';

/// Public interface contract for $pascalName data operations.
abstract interface class ${pascalName}Repository {
  /// Fetches the $pascalName entity or data record by its [id].
  Future<Result<String, ${pascalName}Failure>> getById(String id);

  /// Saves or updates the $pascalName entity.
  Future<Result<void, ${pascalName}Failure>> save(
    String id,
    Map<String, dynamic> data,
  );
}

/// Default implementation of [${pascalName}Repository] with resilient error boundary.
final class Default${pascalName}Repository implements ${pascalName}Repository {
  const Default${pascalName}Repository();

  @override
  Future<Result<String, ${pascalName}Failure>> getById(String id) async {
    return Result.guardAsync<String, ${pascalName}Failure>(
      () async {
        if (id.trim().isEmpty) {
          throw ArgumentError('Identifier cannot be empty.');
        }
        return 'Data for \$id';
      },
      onError: (error, stackTrace) {
        if (error is ArgumentError) {
          return ${pascalName}ValidationFailure(
            message: error.message?.toString() ?? 'Invalid identifier parameter',
            cause: error,
            stackTrace: stackTrace,
          );
        }
        return ${pascalName}UnexpectedFailure(
          message: error.toString(),
          cause: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  @override
  Future<Result<void, ${pascalName}Failure>> save(
    String id,
    Map<String, dynamic> data,
  ) async {
    return Result.guardAsync<void, ${pascalName}Failure>(
      () async {
        if (id.trim().isEmpty) {
          throw ArgumentError('Identifier cannot be empty.');
        }
      },
      onError: (error, stackTrace) {
        if (error is ArgumentError) {
          return ${pascalName}ValidationFailure(
            message: error.message?.toString() ?? 'Invalid parameters',
            cause: error,
            stackTrace: stackTrace,
          );
        }
        return ${pascalName}UnexpectedFailure(
          message: error.toString(),
          cause: error,
          stackTrace: stackTrace,
        );
      },
    );
  }
}
''';
  }

  /// Generates the feature error mapper.
  static String errorMapper(String pascalName, String snakeName) {
    return '''
/// Feature-isolated error presentation mapper for $pascalName.
library;

import 'package:vetro_core/vetro_core.dart';
import '${snakeName}_failure.dart';

/// Translates [${pascalName}Failure] instances into user-facing [UserMessage] representations.
final class ${pascalName}ErrorMapper
    extends BaseFeatureErrorMapper<${pascalName}Failure> {
  const ${pascalName}ErrorMapper();

  @override
  UserMessage mapFeatureError(${pascalName}Failure failure) {
    return switch (failure) {
      ${pascalName}NotFoundFailure(:final message) => UserMessage(
          message: message.isNotEmpty
              ? message
              : 'El elemento solicitado no fue encontrado.',
          title: 'No Encontrado',
          type: MessageType.warning,
        ),
      ${pascalName}NetworkFailure(:final message) => UserMessage(
          message: message.isNotEmpty
              ? message
              : 'Error de conexión con el servidor. Revisa tu red.',
          title: 'Error de Red',
          type: MessageType.error,
        ),
      ${pascalName}ValidationFailure(:final message) => UserMessage(
          message: message.isNotEmpty
              ? message
              : 'Los datos ingresados contienen errores.',
          title: 'Validación Inválida',
          type: MessageType.warning,
        ),
      ${pascalName}UnexpectedFailure(:final message) => UserMessage(
          message: message.isNotEmpty
              ? message
              : 'Ocurrió un error inesperado en $pascalName.',
          title: 'Error Inesperado',
          type: MessageType.error,
        ),
    };
  }
}
''';
  }

  /// Generates the presentation controller.
  static String controller(
    String pascalName,
    String snakeName,
    FeatureStatePattern statePattern,
  ) {
    return '''
/// Presentation controller and state management for $pascalName.
library;

import 'package:vetro_core/vetro_core.dart';
import '../domain/${snakeName}_error_mapper.dart';
import '../domain/${snakeName}_failure.dart';
import '../domain/${snakeName}_repository.dart';

/// Presentation state for the $pascalName feature.
final class ${pascalName}State {
  const ${pascalName}State({
    this.isLoading = false,
    this.data,
    this.errorMessage,
  });

  final bool isLoading;
  final String? data;
  final UserMessage? errorMessage;

  ${pascalName}State copyWith({
    bool? isLoading,
    String? data,
    UserMessage? errorMessage,
  }) {
    return ${pascalName}State(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Controller responsible for managing $pascalName user interactions and presentation state.
final class ${pascalName}Controller {
  ${pascalName}Controller({
    required ${pascalName}Repository repository,
    ${pascalName}ErrorMapper errorMapper = const ${pascalName}ErrorMapper(),
  })  : _repository = repository,
        _errorMapper = errorMapper;

  final ${pascalName}Repository _repository;
  final ${pascalName}ErrorMapper _errorMapper;
  ${pascalName}State state = const ${pascalName}State();

  /// Loads $pascalName data by [id] and updates presentation state safely.
  Future<void> load(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _repository.getById(id);
    state = result.when(
      onSuccess: (data) => state.copyWith(
        isLoading: false,
        data: data,
        errorMessage: null,
      ),
      onFailure: (failure) => state.copyWith(
        isLoading: false,
        errorMessage: _errorMapper.mapFeatureError(failure),
      ),
    );
  }
}
''';
  }

  /// Generates the public barrel file.
  static String barrel(String pascalName, String snakeName) {
    return '''
/// Public feature exports for $pascalName.
library;

export 'domain/${snakeName}_error_mapper.dart';
export 'domain/${snakeName}_failure.dart';
export 'domain/${snakeName}_repository.dart';
export 'presentation/${snakeName}_controller.dart';
''';
  }
}
