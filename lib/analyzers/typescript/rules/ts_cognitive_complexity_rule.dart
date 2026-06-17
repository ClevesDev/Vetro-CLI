import 'package:vetro/analyzers/typescript/rules/ts_rule.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/ts_node.dart';

/// Rule: Cognitive Complexity for TypeScript.
///
/// Measures how difficult a function is to understand for a human reader,
/// penalizing nested control structures recursively.
final class TsCognitiveComplexityRule extends TsRule {
  const TsCognitiveComplexityRule({required super.config});

  @override
  String get id => 'cognitive_complexity';

  @override
  String get name => 'Cognitive Complexity (TS)';

  @override
  String get description =>
      'Flags TypeScript functions whose cognitive complexity exceeds the threshold.';

  @override
  List<Finding> analyze(
    TsNode root,
    String filePath,
    String source,
  ) {
    final maxCognitive =
        config.threshold('max_cognitive_complexity', defaultValue: 15.0).toInt();
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
      final cc = _computeCognitiveComplexity(fn);
      if (cc > maxCognitive) {
        final fnName = _getFunctionName(fn, root);
        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: filePath,
            line: fn.line,
            message: 'Function "$fnName" has cognitive complexity $cc '
                '(threshold: $maxCognitive).',
            evidence: {
              'cognitive_complexity': '$cc',
              'threshold': '$maxCognitive',
            },
          ),
        );
      }
    }

    return findings;
  }

  int _computeCognitiveComplexity(TsNode fnNode) {
    var complexity = 0;

    void visit(TsNode node, TsNode? parent, int nestingLevel, String? parentLogicalOp) {
      // Do not recurse into nested functions (they will be analyzed separately)
      if (node != fnNode &&
          const {
            'FunctionDeclaration',
            'FunctionExpression',
            'ArrowFunctionExpression',
            'ClassMethod',
            'ObjectMethod',
          }.contains(node.type)) {
        return;
      }

      var currentNesting = nestingLevel;
      var currentLogicalOp = parentLogicalOp;

      if (node.type == 'IfStatement') {
        final isElseIf = parent != null &&
            parent.type == 'IfStatement' &&
            parent.raw['alternate'] is Map &&
            node.start == (parent.raw['alternate'] as Map)['start'];

        if (isElseIf) {
          complexity += 1;
        } else {
          complexity += 1 + nestingLevel;
        }
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (const {'ForStatement', 'ForInStatement', 'ForOfStatement'}
          .contains(node.type)) {
        complexity += 1 + nestingLevel;
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (const {'WhileStatement', 'DoWhileStatement'}
          .contains(node.type)) {
        complexity += 1 + nestingLevel;
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (node.type == 'SwitchStatement') {
        complexity += 1;
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (node.type == 'CatchClause') {
        complexity += 1 + nestingLevel;
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (node.type == 'ConditionalExpression') {
        complexity += 1 + nestingLevel;
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (node.type == 'LogicalExpression') {
        final op = node.raw['operator']?.toString();
        if (op == '&&' || op == '||' || op == '??') {
          if (parentLogicalOp != op) {
            complexity += 1;
          }
          currentLogicalOp = op;
        }
      }

      for (final child in node.children) {
        visit(child, node, currentNesting, currentLogicalOp);
      }
    }

    // Find the body/block of the function
    final bodyNode = fnNode.children.firstWhere(
      (child) => const {'BlockStatement', 'ClassBody'}.contains(child.type) ||
          fnNode.type == 'ArrowFunctionExpression',
      orElse: () => fnNode,
    );

    visit(bodyNode, fnNode, 0, null);
    return complexity;
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
