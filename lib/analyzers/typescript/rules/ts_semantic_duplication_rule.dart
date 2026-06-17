import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:vetro/analyzers/typescript/rules/ts_rule.dart';
import 'package:vetro/core/metrics/similarity.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/ts_node.dart';

/// Rule: Semantic Duplication for TypeScript.
///
/// Detects TypeScript functions with high normalized structural similarity,
/// indicating semantic duplication even with different names.
final class TsSemanticDuplicationRule extends TsCrossFileRule {
  const TsSemanticDuplicationRule({required super.config});

  @override
  String get id => 'semantic_duplication';

  @override
  String get name => 'Semantic Duplication (TS)';

  @override
  String get description =>
      'Detects functions with high normalized structural similarity, '
      'indicating semantic duplication even with different names.';

  /// Minimum number of AST nodes to consider a body non-trivial.
  static const _minBodyNodes = 30;

  @override
  Future<List<Finding>> analyzeProject(
    Map<String, TsNode> roots,
    Map<String, String> sources,
  ) async {
    final threshold =
        config.threshold('similarity', defaultValue: 0.80);

    final cachedBodies = <_TsBodyAnalysisCache>[];

    for (final entry in roots.entries) {
      final filePath = entry.key;
      final rootNode = entry.value;

      final functionNodes = rootNode.descendentNodes((node) => const {
            'FunctionDeclaration',
            'FunctionExpression',
            'ArrowFunctionExpression',
            'ClassMethod',
            'ObjectMethod',
          }.contains(node.type));

      for (final fn in functionNodes) {
        final bodyNode = fn.children.firstWhere(
          (child) => const {'BlockStatement', 'ClassBody'}.contains(child.type) ||
              fn.type == 'ArrowFunctionExpression',
          orElse: () => fn,
        );

        final totalNodes = _countNodes(bodyNode);
        if (totalNodes < _minBodyNodes) {
          continue;
        }

        final tokens = bodyNode.extractNodeTypes();
        final hash = fnv1a32(tokens);
        final fnName = _getFunctionName(fn, rootNode);

        cachedBodies.add(
          _TsBodyAnalysisCache(
            _TsFunctionInfo(
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

        // Skip self-comparison (should not happen if indices are distinct)
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

          // Mathematical LCS Pruning
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
          final relPathA = p.relative(a.info.filePath, from: projectRoot);
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
                'location_a': '$relPathA:${a.info.line}',
                'location_b': '$relPathB:${b.info.line}',
              },
            ),
          );
        }
      }
    }

    return findings;
  }

  int _countNodes(TsNode node) {
    var count = 1;
    for (final child in node.children) {
      count += _countNodes(child);
    }
    return count;
  }

  String _canonicalKey(_TsFunctionInfo a, _TsFunctionInfo b) {
    final first = a.filePath.compareTo(b.filePath) < 0 ? a : b;
    final second = first == a ? b : a;
    return '${first.filePath}:${first.line}|${second.filePath}:${second.line}';
  }

  String _getFunctionName(TsNode fnNode, TsNode root) {
    if (fnNode.type == 'FunctionDeclaration') {
      final idMap = fnNode.raw['id'];
      if (idMap is Map && idMap['name'] != null) {
        return idMap['name'].toString();
      }
    } else if (fnNode.type == 'ClassMethod' || fnNode.type == 'ObjectMethod') {
      final keyMap = fnNode.raw['key'];
      if (keyMap is Map && keyMap['name'] != null) {
        return keyMap['name'].toString();
      }
    }

    final declarator = root.descendentNodes((node) =>
        node.type == 'VariableDeclarator' &&
        node.children.any((c) => c.start == fnNode.start && c.end == fnNode.end));

    if (declarator.isNotEmpty) {
      final idMap = declarator.first.raw['id'];
      if (idMap is Map && idMap['name'] != null) {
        return idMap['name'].toString();
      }
    }

    return 'anonymous';
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

final class _TsFunctionInfo {
  const _TsFunctionInfo({
    required this.filePath,
    required this.line,
    required this.name,
    required this.node,
  });

  final String filePath;
  final int line;
  final String name;
  final TsNode node;
}

final class _TsBodyAnalysisCache {
  const _TsBodyAnalysisCache(this.info, this.astTokens, this.astHash);

  final _TsFunctionInfo info;
  final List<String> astTokens;
  final String astHash;
}
