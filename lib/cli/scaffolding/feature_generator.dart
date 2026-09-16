/// Scaffolding engine for generating lean, zero-codegen feature structures in Vetro.
library;

import 'dart:io';
import 'package:path/path.dart' as p;
import 'feature_templates.dart';

/// Supported state management paradigms for generated features.
enum FeatureStatePattern {
  riverpod,
  bloc,
  stateNotifier,
  agnostic;

  static FeatureStatePattern fromString(String value) {
    return switch (value.toLowerCase()) {
      'riverpod' => FeatureStatePattern.riverpod,
      'bloc' || 'cubit' => FeatureStatePattern.bloc,
      'state-notifier' || 'statenotifier' => FeatureStatePattern.stateNotifier,
      'agnostic' || 'pure' => FeatureStatePattern.agnostic,
      _ => FeatureStatePattern.riverpod,
    };
  }
}

/// Options configuring feature generation.
final class FeatureScaffoldOptions {
  const FeatureScaffoldOptions({
    required this.name,
    this.targetPath,
    this.statePattern = FeatureStatePattern.riverpod,
    this.force = false,
  });

  /// The raw feature name (e.g. `auth`, `user_profile`, `billing`).
  final String name;

  /// Custom destination directory. Defaults to `lib/features/<name>`.
  final String? targetPath;

  /// State management pattern to scaffold.
  final FeatureStatePattern statePattern;

  /// Whether to overwrite existing files.
  final bool force;
}

/// Result of a feature scaffolding execution.
final class FeatureScaffoldResult {
  const FeatureScaffoldResult({
    required this.featureName,
    required this.targetDirectory,
    required this.createdFiles,
  });

  final String featureName;
  final String targetDirectory;
  final List<String> createdFiles;
}

/// Core scaffolding engine for Vetro features.
final class FeatureGenerator {
  const FeatureGenerator();

  /// Scaffolds a complete, clean-architecture feature structure.
  Future<FeatureScaffoldResult> generate(
    FeatureScaffoldOptions options, {
    String? workingDirectory,
  }) async {
    final baseDir = workingDirectory ?? Directory.current.path;
    final snakeName = _toSnakeCase(options.name);
    final pascalName = _toPascalCase(options.name);

    if (snakeName.isEmpty) {
      throw ArgumentError('Feature name cannot be empty.');
    }

    final destinationDir = options.targetPath != null
        ? p.normalize(
            p.isAbsolute(options.targetPath!)
                ? options.targetPath!
                : p.join(baseDir, options.targetPath!),
          )
        : p.normalize(p.join(baseDir, 'lib', 'features', snakeName));

    final dir = Directory(destinationDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final domainDir = Directory(p.join(destinationDir, 'domain'));
    if (!domainDir.existsSync()) {
      domainDir.createSync(recursive: true);
    }

    final presentationDir = Directory(p.join(destinationDir, 'presentation'));
    if (!presentationDir.existsSync()) {
      presentationDir.createSync(recursive: true);
    }

    final createdFiles = <String>[];

    // 1. Failure Hierarchy
    final failureFile = File(
      p.join(destinationDir, 'domain', '${snakeName}_failure.dart'),
    );
    _writeFile(
      failureFile,
      FeatureTemplates.failure(pascalName),
      force: options.force,
    );
    createdFiles.add(failureFile.path);

    // 2. Repository Contract & Implementation
    final repositoryFile = File(
      p.join(destinationDir, 'domain', '${snakeName}_repository.dart'),
    );
    _writeFile(
      repositoryFile,
      FeatureTemplates.repository(pascalName, snakeName),
      force: options.force,
    );
    createdFiles.add(repositoryFile.path);

    // 3. Feature Error Mapper
    final errorMapperFile = File(
      p.join(destinationDir, 'domain', '${snakeName}_error_mapper.dart'),
    );
    _writeFile(
      errorMapperFile,
      FeatureTemplates.errorMapper(pascalName, snakeName),
      force: options.force,
    );
    createdFiles.add(errorMapperFile.path);

    // 4. Controller / State Holder
    final controllerFile = File(
      p.join(destinationDir, 'presentation', '${snakeName}_controller.dart'),
    );
    _writeFile(
      controllerFile,
      FeatureTemplates.controller(pascalName, snakeName, options.statePattern),
      force: options.force,
    );
    createdFiles.add(controllerFile.path);

    // 5. Barrel File
    final barrelFile = File(p.join(destinationDir, '$snakeName.dart'));
    _writeFile(
      barrelFile,
      FeatureTemplates.barrel(pascalName, snakeName),
      force: options.force,
    );
    createdFiles.add(barrelFile.path);

    return FeatureScaffoldResult(
      featureName: pascalName,
      targetDirectory: destinationDir,
      createdFiles: createdFiles,
    );
  }

  void _writeFile(File file, String content, {required bool force}) {
    if (file.existsSync() && !force) {
      throw StateError(
        'File already exists at "${file.path}". Use --force (-f) to overwrite.',
      );
    }
    file.writeAsStringSync(content);
  }

  static String _toSnakeCase(String text) {
    return text
        .trim()
        .replaceAllMapped(
          RegExp('([A-Z])'),
          (match) => '_${match.group(1)!.toLowerCase()}',
        )
        .replaceAll(RegExp(r'[-\s]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceFirst(RegExp('^_'), '')
        .replaceFirst(RegExp(r'_$'), '');
  }

  static String _toPascalCase(String text) {
    final snake = _toSnakeCase(text);
    return snake
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join();
  }
}
