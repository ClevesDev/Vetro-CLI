import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:vetro/analyzers/typescript/rules/ts_rule.dart';
import 'package:vetro/core/metrics/dependency_graph.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/ts_node.dart';

/// Rule: Tight Coupling for TypeScript.
///
/// Detects TypeScript files that are excessively interconnected based on imports.
final class TsTightCouplingRule extends TsCrossFileRule {
  const TsTightCouplingRule({required super.config});

  @override
  String get id => 'tight_coupling';

  @override
  String get name => 'Tight Coupling (TS)';

  @override
  String get description =>
      'Detects TypeScript files with excessive import/export coupling.';

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

  List<String> _extractImports(TsNode rootNode) {
    final imports = <String>[];
    // Find all ImportDeclaration nodes.
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
