import 'dart:math' as math;
import 'package:vetro/analyzers/typescript/rules/ts_rule.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/ts_node.dart';

/// Rule: Low Entropy for TypeScript.
///
/// Flags complex or long functions whose AST node type entropy or identifier
/// entropy is abnormally low (suggesting highly repetitive boilerplate or generated code).
final class TsLowEntropyRule extends TsRule {
  const TsLowEntropyRule({required super.config});

  @override
  String get id => 'low_entropy';

  @override
  String get name => 'Low Entropy (TS)';

  @override
  String get description =>
      'Flags complex or long TypeScript functions whose AST node type entropy is abnormally low.';

  @override
  List<Finding> analyze(
    TsNode root,
    String filePath,
    String source,
  ) {
    final minEntropy = config.threshold('min_entropy', defaultValue: 1.8);
    final minIdentEntropy =
        config.threshold('min_identifier_entropy', defaultValue: 2.0);
    final minNodes = config.threshold('min_nodes', defaultValue: 30.0).toInt();
    final findings = <Finding>[];

    // Find all function-like nodes.
    final functionNodes = root.descendentNodes((node) => const {
          'FunctionDeclaration',
          'FunctionExpression',
          'ArrowFunctionExpression',
          'ClassMethod',
          'ObjectMethod',
        }.contains(node.type));

    for (final fn in functionNodes) {
      // Find the body node
      final bodyNode = fn.children.firstWhere(
        (child) => const {'BlockStatement', 'ClassBody'}.contains(child.type) ||
            fn.type == 'ArrowFunctionExpression',
        orElse: () => fn,
      );

      final totalNodes = _countNodes(bodyNode);
      if (totalNodes >= minNodes) {
        final h = _computeShannonEntropy(bodyNode);
        if (h < minEntropy) {
          final fnName = _getFunctionName(fn, root);
          findings.add(
            Finding(
              ruleId: id,
              ruleName: name,
              severity: severity,
              filePath: filePath,
              line: fn.line,
              message: 'Function "$fnName" has Shannon entropy ${h.toStringAsFixed(3)} '
                  'with $totalNodes nodes (threshold: ${minEntropy.toStringAsFixed(3)}).',
              evidence: {
                'shannon_entropy': h.toStringAsFixed(3),
                'node_count': '$totalNodes',
                'threshold': minEntropy.toStringAsFixed(3),
              },
            ),
          );
        } else {
          final hIdent = _computeIdentifierEntropy(bodyNode);
          if (hIdent < minIdentEntropy) {
            final fnName = _getFunctionName(fn, root);
            findings.add(
              Finding(
                ruleId: id,
                ruleName: name,
                severity: severity,
                filePath: filePath,
                line: fn.line,
                message: 'Function "$fnName" has low identifier Shannon entropy ${hIdent.toStringAsFixed(3)} '
                    'with $totalNodes nodes (threshold: ${minIdentEntropy.toStringAsFixed(3)}).',
                evidence: {
                  'identifier_entropy': hIdent.toStringAsFixed(3),
                  'node_count': '$totalNodes',
                  'threshold': minIdentEntropy.toStringAsFixed(3),
                },
              ),
            );
          }
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

  double _computeShannonEntropy(TsNode rootNode) {
    final counts = <String, int>{};
    var total = 0;

    void count(TsNode n) {
      counts[n.type] = (counts[n.type] ?? 0) + 1;
      total++;
      for (final child in n.children) {
        count(child);
      }
    }

    count(rootNode);
    if (total == 0) return 0.0;

    var entropy = 0.0;
    for (final countVal in counts.values) {
      final p = countVal / total;
      entropy -= p * (math.log(p) / math.log(2));
    }
    return entropy;
  }

  double _computeIdentifierEntropy(TsNode rootNode) {
    final counts = <String, int>{};
    var total = 0;

    const keywords = {
      'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger',
      'default', 'delete', 'do', 'else', 'export', 'extends', 'false',
      'finally', 'for', 'function', 'if', 'import', 'in', 'instanceof',
      'new', 'null', 'return', 'super', 'switch', 'this', 'throw', 'true',
      'try', 'typeof', 'var', 'void', 'while', 'with', 'yield',
      'let', 'package', 'private', 'protected', 'public', 'static',
      'any', 'boolean', 'constructor', 'declare', 'get', 'module',
      'require', 'number', 'readonly', 'set', 'string', 'symbol',
      'type', 'from', 'of', 'as', 'keyof', 'is'
    };

    void count(TsNode n) {
      if (n.type == 'Identifier') {
        final name = n.raw['name']?.toString();
        if (name != null && name.isNotEmpty && !keywords.contains(name)) {
          counts[name] = (counts[name] ?? 0) + 1;
          total++;
        }
      }
      for (final child in n.children) {
        count(child);
      }
    }

    count(rootNode);
    if (total == 0) return 0.0;

    var entropy = 0.0;
    for (final countVal in counts.values) {
      final p = countVal / total;
      entropy -= p * (math.log(p) / math.log(2));
    }
    return entropy;
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
}
