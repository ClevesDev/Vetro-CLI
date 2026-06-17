import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:vetro/analyzers/python/rules/py_rule.dart';
import 'package:vetro/core/metrics/similarity.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/py_node.dart';

/// Rule: Semantic Duplication for Python.
final class PySemanticDuplicationRule extends PyCrossFileRule {
  const PySemanticDuplicationRule({required super.config});

  @override
  String get id => 'semantic_duplication';

  @override
  String get name => 'Semantic Duplication (Python)';

  @override
  String get description =>
      'Detects Python functions with high normalized structural similarity, '
      'indicating semantic duplication even with different names.';

  static const _minBodyNodes = 30;

  @override
  Future<List<Finding>> analyzeProject(
    Map<String, PyNode> roots,
    Map<String, String> sources,
  ) async {
    final threshold =
        config.threshold('similarity', defaultValue: 0.80);

    final cachedBodies = <_PyBodyAnalysisCache>[];

    for (final entry in roots.entries) {
      final filePath = entry.key;
      final rootNode = entry.value;

      final functionNodes = rootNode.descendentNodes((node) => const {
            'FunctionDef',
            'AsyncFunctionDef',
          }.contains(node.type));

      for (final fn in functionNodes) {
        final totalNodes = _countNodes(fn);
        if (totalNodes < _minBodyNodes) {
          continue;
        }

        final tokens = fn.extractNodeTypes();
        final hash = fnv1a32(tokens);
        final fnName = fn.raw['name']?.toString() ?? 'anonymous';

        cachedBodies.add(
          _PyBodyAnalysisCache(
            _PyFunctionInfo(
              filePath: filePath,
              line: fn.line,
              name: fnName,
              node: fn,
            ),
            tokens,
            hash,
          ),
        );
      }
    }

    final findings = <Finding>[];
    final reported = <String>{};

    for (var i = 0; i < cachedBodies.length; i++) {
      for (var j = i + 1; j < cachedBodies.length; j++) {
        final a = cachedBodies[i];
        final b = cachedBodies[j];

        if (a.info.filePath == b.info.filePath && a.info.line == b.info.line) {
          continue;
        }

        var sim = 0.0;
        if (a.astHash == b.astHash) {
          sim = 1.0;
        } else {
          final lenA = a.astTokens.length;
          final lenB = b.astTokens.length;
          final minLen = lenA < lenB ? lenA : lenB;
          final maxLen = lenA > lenB ? lenA : lenB;

          if (minLen < maxLen * (threshold / (2.0 - threshold))) {
            continue;
          }

          sim = lcsSimilarity(a.astTokens, b.astTokens);
        }

        if (sim >= threshold) {
          final key = _canonicalKey(a.info, b.info);
          if (reported.contains(key)) continue;
          reported.add(key);

          final percentage = (sim * 100).toStringAsFixed(1);
          final projectRoot = _findProjectRoot(a.info.filePath);
          final relPathB = p.relative(b.info.filePath, from: projectRoot);

          findings.add(
            Finding(
              ruleId: id,
              ruleName: name,
              severity: severity,
              filePath: a.info.filePath,
              line: a.info.line,
              message: 'Function "${a.info.name}" is $percentage% semantically '
                  'similar to "${b.info.name}" at $relPathB:${b.info.line}.',
              evidence: {
                'similarity': '$percentage%',
                'function_a': a.info.name,
                'function_b': b.info.name,
                'location_a': '${p.relative(a.info.filePath, from: projectRoot)}:${a.info.line}',
                'location_b': '$relPathB:${b.info.line}',
              },
            ),
          );
        }
      }
    }

    return findings;
  }

  int _countNodes(PyNode node) {
    var count = 1;
    for (final child in node.children) {
      count += _countNodes(child);
    }
    return count;
  }

  String _canonicalKey(_PyFunctionInfo a, _PyFunctionInfo b) {
    final first = a.filePath.compareTo(b.filePath) < 0 ? a : b;
    final second = first == a ? b : a;
    return '${first.filePath}:${first.line}|${second.filePath}:${second.line}';
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

final class _PyFunctionInfo {
  const _PyFunctionInfo({
    required this.filePath,
    required this.line,
    required this.name,
    required this.node,
  });

  final String filePath;
  final int line;
  final String name;
  final PyNode node;
}

final class _PyBodyAnalysisCache {
  const _PyBodyAnalysisCache(this.info, this.astTokens, this.astHash);

  final _PyFunctionInfo info;
  final List<String> astTokens;
  final String astHash;
}
