/// Rule: Tight Coupling — detects files that are excessively interconnected.
///
/// **Mathematical basis**: Coupling metric calculated via DependencyGraph.
///
/// We count incoming (fan-in) and outgoing (fan-out) imports, dividing by
/// the total number of files in the project. If a file's coupling ratio exceeds
/// a threshold (default 0.25), it indicates a "god file" or hub.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/metrics/dependency_graph.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Flags files whose normalized coupling ratio exceeds the configured threshold.
///
/// Tightly coupled files are brittle because changes to them ripple across the
/// project, and they frequently break when other files change.
final class TightCouplingRule extends CrossFileRule {
  /// Creates a [TightCouplingRule] with the given [config].
  const TightCouplingRule({required super.config});

  @override
  String get id => 'tight_coupling';

  @override
  String get name => 'Tight Coupling';

  @override
  String get description => 'Detects files with excessive import/export coupling.';

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

    final maxCoupling = config.threshold('max_coupling', defaultValue: 0.25);
    final findings = <Finding>[];

    for (final node in graph.nodes) {
      // We check coupling ratio because files connected to a high percentage of the project
      // represent architectural bottlenecks and sources of fragility.
      final c = graph.coupling(node);
      if (c > maxCoupling) {
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
            message: 'File "$relativePath" has tight coupling: '
                '${(c * 100).toStringAsFixed(1)}% (fan-in: $fanInCount, fan-out: $fanOutCount).',
            evidence: {
              'coupling': '${(c * 100).toStringAsFixed(1)}%',
              'fan_in': '$fanInCount',
              'fan_out': '$fanOutCount',
              'threshold': '${(maxCoupling * 100).toStringAsFixed(1)}%',
            },
          ),
        );
      }
    }

    return findings;
  }
}
