import 'package:vetro/analyzers/typescript/rules/ts_rule.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/ts_node.dart';

/// Rule: Cyclomatic Complexity for TypeScript.
///
/// CC = 1 + Σ(decision points).
/// Decision points counted in TypeScript/ESTree AST:
/// - IfStatement
/// - ForStatement, ForInStatement, ForOfStatement
/// - WhileStatement, DoWhileStatement
/// - SwitchCase (only if test is present, i.e., non-default)
/// - CatchClause
/// - ConditionalExpression (ternary ? :)
/// - LogicalExpression (with operator &&, ||, or ??)
final class TsCyclomaticComplexityRule extends TsRule {
  const TsCyclomaticComplexityRule({required super.config});

  @override
  String get id => 'cyclomatic_complexity';

  @override
  String get name => 'Cyclomatic Complexity (TS)';

  @override
  String get description =>
      'Flags TypeScript functions whose cyclomatic complexity exceeds the threshold.';

  @override
  List<Finding> analyze(
    TsNode root,
    String filePath,
    String source,
  ) {
    final maxCC =
        config.threshold('max_complexity', defaultValue: 15.0).toInt();
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
      final cc = _computeCyclomaticComplexity(fn);
      if (cc > maxCC) {
        final fnName = _getFunctionName(fn, root);
        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: filePath,
            line: fn.line,
            message: 'Function "$fnName" has cyclomatic complexity $cc '
                '(threshold: $maxCC).',
            evidence: {
              'cyclomatic_complexity': '$cc',
              'threshold': '$maxCC',
            },
          ),
        );
      }
    }

    return findings;
  }

  int _computeCyclomaticComplexity(TsNode fnNode) {
    var decisionPoints = 0;

    // Helper function to recursively count decision points under the function body.
    void count(TsNode node) {
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

      if (node.type == 'IfStatement') {
        decisionPoints++;
      } else if (const {'ForStatement', 'ForInStatement', 'ForOfStatement'}
          .contains(node.type)) {
        decisionPoints++;
      } else if (const {'WhileStatement', 'DoWhileStatement'}
          .contains(node.type)) {
        decisionPoints++;
      } else if (node.type == 'SwitchCase') {
        // Only count if there is a test (default case does not count)
        if (node.raw['test'] != null) {
          decisionPoints++;
        }
      } else if (node.type == 'CatchClause') {
        decisionPoints++;
      } else if (node.type == 'ConditionalExpression') {
        decisionPoints++;
      } else if (node.type == 'LogicalExpression') {
        final op = node.raw['operator']?.toString();
        if (op == '&&' || op == '||' || op == '??') {
          decisionPoints++;
        }
      }

      for (final child in node.children) {
        count(child);
      }
    }

    // Find the body/block of the function
    final bodyNode = fnNode.children.firstWhere(
      (child) => const {'BlockStatement', 'ClassBody'}.contains(child.type) ||
          fnNode.type == 'ArrowFunctionExpression',
      orElse: () => fnNode,
    );

    count(bodyNode);
    return 1 + decisionPoints;
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

    // If it's an arrow function or function expression, check if it's assigned to a variable.
    // We can scan the parent hierarchy or do a quick search in the root to see if this node is
    // the init of a VariableDeclarator.
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
