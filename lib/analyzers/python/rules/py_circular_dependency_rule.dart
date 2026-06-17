import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:vetro/analyzers/python/rules/py_rule.dart';
import 'package:vetro/core/metrics/dependency_graph.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/py_node.dart';

/// Rule: Circular Dependency for Python.
final class PyCircularDependencyRule extends PyCrossFileRule {
  const PyCircularDependencyRule({required super.config});

  @override
  String get id => 'circular_dependency';

  @override
  String get name => 'Circular Dependency (Python)';

  @override
  String get description => 'Detects Python file-level circular import dependencies.';

  @override
  Future<List<Finding>> analyzeProject(
    Map<String, PyNode> roots,
    Map<String, String> sources,
  ) async {
    if (roots.isEmpty) return const [];

    final projectRoot = _findProjectRoot(roots.keys.first);

    final graph = DependencyGraph();
    for (final filePath in roots.keys) {
      graph.addNode(filePath);
    }

    final allFiles = roots.keys.toSet();

    for (final entry in roots.entries) {
      final filePath = entry.key;
      final rootNode = entry.value;

      final imports = _extractImports(rootNode);
      for (final import in imports) {
        final resolvedPath = _resolveImport(import.uri, import.level, filePath, allFiles);
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
          line: 1,
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
          cycle.add(neighbor);
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
    rotated.add(rotated.first);
    return rotated;
  }

  List<({String uri, int level})> _extractImports(PyNode rootNode) {
    final imports = <({String uri, int level})>[];

    final importNodes = rootNode.descendentNodes((node) => const {
          'Import',
          'ImportFrom',
        }.contains(node.type));

    for (final node in importNodes) {
      if (node.type == 'Import') {
        final namesList = node.raw['names'];
        if (namesList is List) {
          for (final nameNode in namesList) {
            if (nameNode is Map) {
              final importUri = nameNode['name']?.toString() ?? '';
              imports.add((uri: importUri, level: 0));
            }
          }
        }
      } else if (node.type == 'ImportFrom') {
        final module = node.raw['module']?.toString() ?? '';
        final level = node.raw['level'] is int ? node.raw['level'] as int : 0;
        imports.add((uri: module, level: level));
      }
    }
    return imports;
  }

  String? _resolveImport(String importUri, int level, String filePath, Set<String> allFiles) {
    if (importUri.isEmpty && level == 0) return null;

    final dir = p.dirname(filePath);

    if (level > 0) {
      var relativeDir = dir;
      for (var i = 1; i < level; i++) {
        relativeDir = p.dirname(relativeDir);
      }

      final targetPath = p.normalize(p.join(relativeDir, importUri.replaceAll('.', '/')));

      final candidates = [
        targetPath,
        '$targetPath.py',
        p.join(targetPath, '__init__.py'),
      ];

      for (final candidate in candidates) {
        if (allFiles.contains(candidate)) {
          return candidate;
        }
      }
      return null;
    }

    final parts = importUri.split('.');
    final targetPath = p.normalize(p.join(dir, parts.join('/')));
    final candidates = [
      targetPath,
      '$targetPath.py',
      p.join(targetPath, '__init__.py'),
    ];

    for (final candidate in candidates) {
      if (allFiles.contains(candidate)) {
        return candidate;
      }
    }

    for (final file in allFiles) {
      final normalizedFile = p.normalize(file);
      final suffix = parts.join('/') + '.py';
      final initSuffix = parts.join('/') + '/__init__.py';
      if (normalizedFile.endsWith(suffix) || normalizedFile.endsWith(initSuffix)) {
        return normalizedFile;
      }
    }

    return null;
  }

  String _findProjectRoot(String filePath) {
    var dir = p.dirname(filePath);
    while (dir != p.separator && dir.isNotEmpty) {
      if (File(p.join(dir, 'requirements.txt')).existsSync() ||
          File(p.join(dir, 'pyproject.toml')).existsSync() ||
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
