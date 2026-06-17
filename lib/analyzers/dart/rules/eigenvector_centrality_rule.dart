import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/metrics/dependency_graph.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Rule: Eigenvector Centrality — flags files that are central dependency bottlenecks in the import graph.
final class EigenvectorCentralityRule extends CrossFileRule {
  const EigenvectorCentralityRule({required super.config});

  @override
  String get id => 'eigenvector_centrality';

  @override
  String get name => 'Eigenvector Centrality';

  @override
  String get description =>
      'Detects files with excessive PageRank/eigenvector centrality in the dependency graph.';

  @override
  Future<List<Finding>> analyzeProject(
    Map<String, CompilationUnit> units,
    Map<String, String> sources,
  ) async {
    // Note: The purpose of this rule is to detect global import bottlenecks using graph eigenvector centrality.
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
        final resolvedPath =
            resolveImport(importUri, filePath, projectRoot, packageName);
        if (resolvedPath != null && units.containsKey(resolvedPath)) {
          graph.addEdge(filePath, resolvedPath);
        }
      }
    }

    final maxCentrality =
        config.threshold('max_centrality', defaultValue: 0.40);
    final centralities = graph.eigenvectorCentrality();
    final findings = <Finding>[];

    for (final entry in centralities.entries) {
      final node = entry.key;
      final score = entry.value;

      if (score > maxCentrality) {
        final relativePath = p.relative(node, from: projectRoot);
        final fanInCount = graph.fanIn(node);
        final fanOutCount = graph.fanOut(node);

        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: node,
            line: 1, // File-level finding
            message: 'File "$relativePath" has high eigenvector centrality: '
                '${score.toStringAsFixed(3)} (fan-in: $fanInCount, fan-out: $fanOutCount).',
            evidence: {
              'eigenvector_centrality': score.toStringAsFixed(3),
              'fan_in': '$fanInCount',
              'fan_out': '$fanOutCount',
              'threshold': maxCentrality.toStringAsFixed(3),
            },
          ),
        );
      }
    }

    return findings;
  }
}
