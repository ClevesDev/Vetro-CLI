import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:vetro/analyzers/typescript/rules/ts_rule.dart';
import 'package:vetro/core/metrics/dependency_graph.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/ts_node.dart';

/// Rule: Circular Dependency for TypeScript.
///
/// Detects file-level circular import cycles in TypeScript projects.
final class TsCircularDependencyRule extends TsCrossFileRule {
  const TsCircularDependencyRule({required super.config});

  @override
  String get id => 'circular_dependency';

  @override
  String get name => 'Circular Dependency (TS)';

  @override
  String get description => 'Detects file-level circular import dependencies.';

  @override
  Future<List<Finding>> analyzeProject(
    Map<String, TsNode> roots,
    Map<String, String> sources,
  ) async {
    if (roots.isEmpty) return const [];

    final projectRoot = _findProjectRoot(roots.keys.first);

    // Build the dependency graph of all files in the project.
    final graph = DependencyGraph();
    for (final filePath in roots.keys) {
      graph.addNode(filePath);
    }

    final allFiles = roots.keys.toSet();

    for (final entry in roots.entries) {
      final filePath = entry.key;
      final rootNode = entry.value;

      final imports = _extractImports(rootNode);
      for (final importUri in imports) {
        final resolvedPath = _resolveImport(importUri, filePath, allFiles);
        if (resolvedPath != null) {
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

  List<String> _extractImports(TsNode rootNode) {
    final imports = <String>[];
    final importDeclarations = rootNode.descendentNodes((node) =>
        node.type == 'ImportDeclaration' ||
        node.type == 'ExportNamedDeclaration' ||
        node.type == 'ExportAllDeclaration');

    for (final decl in importDeclarations) {
      final sourceMap = decl.raw['source'];
      if (sourceMap is Map && sourceMap['value'] != null) {
        imports.add(sourceMap['value'].toString());
      }
    }
    return imports;
  }

  String? _resolveImport(String importUri, String filePath, Set<String> allFiles) {
    if (!importUri.startsWith('.') && !importUri.startsWith('/')) {
      return null;
    }

    final dir = p.dirname(filePath);
    final targetPath = p.normalize(p.join(dir, importUri));

    final candidates = [
      targetPath,
      '$targetPath.ts',
      '$targetPath.tsx',
      p.join(targetPath, 'index.ts'),
      p.join(targetPath, 'index.tsx'),
    ];

    for (final candidate in candidates) {
      if (allFiles.contains(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  String _findProjectRoot(String filePath) {
    var dir = p.dirname(filePath);
    while (dir != p.separator && dir.isNotEmpty) {
      if (Directory(p.join(dir, 'tsconfig.json')).existsSync() ||
          File(p.join(dir, 'package.json')).existsSync() ||
          File(p.join(dir, 'vetro.yaml')).existsSync()) {
        return dir;
      }
      final parent = p.dirname(dir);
      if (parent == dir) break;
      dir = parent;
    }
    return p.dirname(filePath);
  }
}
