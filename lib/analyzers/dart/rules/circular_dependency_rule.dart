/// Rule: Circular Dependency — detects file-level circular import cycles.
///
/// **Mathematical basis**: Cycle detection in directed dependency graphs.
///
/// A cycle is a path of file imports: A -> B -> C -> A.
/// We build a project-wide import dependency graph and run a DFS cycle-detection
/// algorithm to find all loops, rotating and deduplicating cycles for canonical reporting.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/metrics/dependency_graph.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Detects cycles in the file import dependency graph.
///
/// Circular dependencies indicate tight structural coupling, making it
/// difficult to split or mock modules.
final class CircularDependencyRule extends CrossFileRule {
  /// Creates a [CircularDependencyRule] with the given [config].
  const CircularDependencyRule({required super.config});

  @override
  String get id => 'circular_dependency';

  @override
  String get name => 'Circular Dependency';

  @override
  String get description => 'Detects file-level circular import dependencies.';

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
        // We only add internal dependencies that are part of the scanned files
        // to avoid tracing external package graphs.
        if (resolvedPath != null && units.containsKey(resolvedPath)) {
          graph.addEdge(filePath, resolvedPath);
        }
      }
    }

    final findings = <Finding>[];
    final cycles = _findCycles(graph);
    final reported = <String>{};

    for (final cycle in cycles) {
      final canon = _canonicalCycle(cycle);
      final key = canon.join('|');
      // We check our set of reported cycles because different traversal starting
      // points can yield the same cycle (e.g. A->B->A and B->A->B).
      if (reported.contains(key)) continue;
      reported.add(key);

      final relativeCycle = canon.map((path) => p.relative(path, from: projectRoot)).toList();
      final pathStr = relativeCycle.join(' -> ');

      findings.add(
        Finding(
          ruleId: id,
          ruleName: name,
          severity: severity,
          filePath: canon.first,
          line: 1, // File-level finding
          message: 'Circular dependency cycle detected: $pathStr',
          evidence: {
            'cycle_path': pathStr,
            'cycle_length': '${relativeCycle.length - 1}',
          },
        ),
      );
    }

    return findings;
  }

  /// Finds all cycles in a directed dependency graph using a DFS path stack.
  List<List<String>> _findCycles(DependencyGraph graph) {
    final visited = <String>{};
    final stack = <String>[];
    final inStack = <String>{};
    final cycles = <List<String>>[];

    void dfs(String node) {
      visited.add(node);
      stack.add(node);
      inStack.add(node);

      for (final neighbor in graph.dependenciesOf(node)) {
        // We check if the neighbor is already in our recursion stack because
        // that indicates we have looped back to an ancestor, forming a cycle.
        if (inStack.contains(neighbor)) {
          final cycleStart = stack.indexOf(neighbor);
          final cycle = stack.sublist(cycleStart);
          cycle.add(neighbor); // Close the cycle
          cycles.add(cycle);
        } else if (!visited.contains(neighbor)) {
          dfs(neighbor);
        }
      }

      stack.removeLast();
      inStack.remove(node);
    }

    for (final node in graph.nodes) {
      if (!visited.contains(node)) {
        dfs(node);
      }
    }

    return cycles;
  }

  /// Rotates a cycle path so it starts and ends with the lexicographically smallest path.
  ///
  /// We do this because A->B->C->A and B->C->A->B are the same cycle, and rotating them
  /// to a standard canonical form allows us to deduplicate them.
  List<String> _canonicalCycle(List<String> cycle) {
    final path = cycle.sublist(0, cycle.length - 1);
    var minIndex = 0;
    for (var i = 1; i < path.length; i++) {
      if (path[i].compareTo(path[minIndex]) < 0) {
        minIndex = i;
      }
    }
    final rotated = [...path.sublist(minIndex), ...path.sublist(0, minIndex)];
    rotated.add(rotated.first); // Close the cycle loop
    return rotated;
  }
}
