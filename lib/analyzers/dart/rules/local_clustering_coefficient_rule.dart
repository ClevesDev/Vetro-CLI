/// Rule: Local Clustering Coefficient — detects files that act as chaotic
/// import bridges/bridges of unmodular dependencies.
///
/// **Mathematical basis**: Local Clustering Coefficient on directed graphs.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/metrics/dependency_graph.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Flags files whose local clustering coefficient falls below the configured threshold.
///
/// A low clustering coefficient indicates that the node's neighbors are not
/// connected to each other, meaning the node is acting as a chaotic, unmodular
/// bridge/junction between disparate parts of the system (common in AI patching).
final class LocalClusteringCoefficientRule extends CrossFileRule {
  /// Creates a [LocalClusteringCoefficientRule] with the given [config].
  const LocalClusteringCoefficientRule({required super.config});

  @override
  String get id => 'local_clustering_coefficient';

  @override
  String get name => 'Local Clustering Coefficient';

  @override
  String get description =>
      'Detects files with low local clustering in the import graph, indicating unmodular design.';

  @override
  Future<List<Finding>> analyzeProject(
    Map<String, CompilationUnit> units,
    Map<String, String> sources,
  ) async {
    if (units.isEmpty) return const [];

    final projectRoot = findProjectRoot(units.keys.first);
    if (projectRoot == null) return const [];

    final packageName = getPackageName(projectRoot) ?? '';

    // Build the dependency graph of all files in the project.
    final graph = DependencyGraph();
    for (final filePath in units.keys) {
      graph.addNode(filePath);
    }

    for (final entry in units.entries) {
      final filePath = entry.key;
      final unit = entry.value;

      for (final importUri in extractImports(unit)) {
        final resolvedPath = resolveImport(importUri, filePath, projectRoot, packageName);
        if (resolvedPath != null && units.containsKey(resolvedPath)) {
          graph.addEdge(filePath, resolvedPath);
        }
      }
    }

    final minClustering = config.threshold('min_clustering', defaultValue: 0.15);
    final minConnections = config.threshold('min_connections', defaultValue: 4.0).toInt();
    final findings = <Finding>[];

    for (final node in graph.nodes) {
      final neighbors = <String>{
        ...graph.dependenciesOf(node),
        ...graph.dependentsOf(node),
      }..remove(node);

      final connections = neighbors.length;
      if (connections < minConnections) continue;

      final coef = graph.localClusteringCoefficient(node);
      if (coef < minClustering) {
        final relativePath = p.relative(node, from: projectRoot);
        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: node,
            line: 1, // File-level finding
            message: 'File "$relativePath" has low local clustering coefficient: '
                '${(coef * 100).toStringAsFixed(1)}% (neighbors: $connections, threshold: >= ${(minClustering * 100).toStringAsFixed(1)}%).',
            evidence: {
              'clustering_coefficient': '${(coef * 100).toStringAsFixed(1)}%',
              'neighbors': '$connections',
              'threshold': '${(minClustering * 100).toStringAsFixed(1)}%',
            },
          ),
        );
      }
    }

    return findings;
  }
}
