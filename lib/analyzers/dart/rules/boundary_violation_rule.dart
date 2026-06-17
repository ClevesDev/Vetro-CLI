import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Rule: Boundary Violation — Enforces Clean Architecture dependency flow.
///
/// **Logical basis**: Layers are defined in a strict partial order of dependency
/// from innermost (core domain logic) to outermost (UI, DB, frameworks).
/// Import arrows (depend-on relations) must only point inward (outer to inner).
/// Any import from an inner layer to an outer layer is flagged as a violation.
final class BoundaryViolationRule extends CrossFileRule {
  const BoundaryViolationRule({required super.config});

  @override
  String get id => 'boundary_violation';

  @override
  String get name => 'Boundary Violation';

  @override
  String get description =>
      'Flags import statements that violate Clean Architecture layering boundaries '
      '(e.g., inner layers importing outer layers).';

  @override
  Future<List<Finding>> analyzeProject(
    Map<String, CompilationUnit> units,
    Map<String, String> sources,
  ) async {
    if (units.isEmpty) return const [];

    final projectRoot = findProjectRoot(units.keys.first);
    if (projectRoot == null) return const [];

    final packageName = getPackageName(projectRoot) ?? '';

    // Retrieve configured layers list.
    final dynamic layersOpt = config.options['layers'];
    final List<String> layers = layersOpt is List
        ? layersOpt.map((e) => e.toString()).toList()
        : const ['domain', 'application', 'infrastructure', 'presentation'];

    if (layers.isEmpty) return const [];

    final findings = <Finding>[];

    for (final entry in units.entries) {
      final filePath = entry.key;
      final unit = entry.value;

      final sourceLayerIndex = _getLayerIndex(filePath, layers, projectRoot);
      // Skip if this file is not part of any defined layer.
      if (sourceLayerIndex == null) continue;

      for (final directive in unit.directives.whereType<ImportDirective>()) {
        final importUri = directive.uri.stringValue;
        if (importUri == null) continue;

        final resolvedPath =
            resolveImport(importUri, filePath, projectRoot, packageName);
        if (resolvedPath == null || !units.containsKey(resolvedPath)) continue;

        final targetLayerIndex = _getLayerIndex(resolvedPath, layers, projectRoot);
        // Skip if target file is not part of any defined layer.
        if (targetLayerIndex == null) continue;

        // Clean Architecture Violation: Inner layer imports outer layer
        if (sourceLayerIndex < targetLayerIndex) {
          final line = unit.lineInfo.getLocation(directive.offset).lineNumber;
          final sourceRelative = p.relative(filePath, from: projectRoot);
          final targetRelative = p.relative(resolvedPath, from: projectRoot);

          findings.add(
            Finding(
              ruleId: id,
              ruleName: name,
              severity: severity,
              filePath: filePath,
              line: line,
              message: 'Boundary violation: Layer "${layers[sourceLayerIndex]}" '
                  '(innermost) cannot import outer layer "${layers[targetLayerIndex]}" '
                  '(imported file: "$targetRelative").',
              evidence: {
                'source_file': sourceRelative,
                'source_layer': layers[sourceLayerIndex],
                'target_file': targetRelative,
                'target_layer': layers[targetLayerIndex],
                'import_statement': directive.toString().trim(),
              },
            ),
          );
        }
      }
    }

    return findings;
  }

  /// Returns the index of the layer that [filePath] belongs to, or null if unlayered.
  int? _getLayerIndex(String filePath, List<String> layers, String projectRoot) {
    final relativePath = p.relative(filePath, from: projectRoot);
    final segments = p.split(p.normalize(relativePath));

    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      if (layer.contains('/') || layer.contains('\\')) {
        final normalizedLayer = p.normalize(layer);
        if (p.normalize(relativePath).contains(normalizedLayer)) {
          return i;
        }
      } else {
        if (segments.contains(layer)) {
          return i;
        }
      }
    }
    return null;
  }
}
