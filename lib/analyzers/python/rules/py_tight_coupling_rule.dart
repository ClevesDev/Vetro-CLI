import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:vetro/analyzers/python/rules/py_rule.dart';
import 'package:vetro/core/metrics/dependency_graph.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/py_node.dart';

/// Rule: Tight Coupling for Python.
final class PyTightCouplingRule extends PyCrossFileRule {
  const PyTightCouplingRule({required super.config});

  @override
  String get id => 'tight_coupling';

  @override
  String get name => 'Tight Coupling (Python)';

  @override
  String get description =>
      'Detects Python files with excessive import coupling.';

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

    final maxCoupling = config.threshold('max_coupling', defaultValue: 0.25);
    final minFanOut = config.options['min_fan_out'] is num
        ? (config.options['min_fan_out'] as num).toInt()
        : 0;
    final findings = <Finding>[];

    for (final node in graph.nodes) {
      final c = graph.coupling(node);
      final fanOutCount = graph.fanOut(node);
      if (c > maxCoupling && fanOutCount >= minFanOut) {
        final relativePath = p.relative(node, from: projectRoot);
        final fanInCount = graph.fanIn(node);

        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: node,
            line: 1,
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
