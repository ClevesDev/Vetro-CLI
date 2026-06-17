import 'package:vetro/analyzers/typescript/rules/ts_rule.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/ts_node.dart';

/// Rule: Intent Gap for TypeScript.
///
/// Cross-references complexity against the presence of intent-bearing comments.
/// A function is flagged when complexity >= min_complexity AND intentComments = 0.
final class TsIntentGapRule extends TsRule {
  const TsIntentGapRule({required super.config});

  @override
  String get id => 'intent_gap';

  @override
  String get name => 'Intent Gap (TS)';

  @override
  String get description =>
      'Flags complex TypeScript functions that lack intent documentation (no comments explaining why).';

  @override
  List<Finding> analyze(
    TsNode root,
    String filePath,
    String source,
  ) {
    final minCC =
        config.threshold('min_complexity', defaultValue: 5.0).toInt();
    final findings = <Finding>[];

    // Find all function-like nodes.
    final functionNodes = root.descendentNodes((node) => const {
          'FunctionDeclaration',
          'FunctionExpression',
          'ArrowFunctionExpression',
          'ClassMethod',
          'ObjectMethod',
        }.contains(node.type));

    // Get all comments from the root File AST.
    final commentsList = root.raw['comments'];
    final comments = <Map<String, dynamic>>[];
    if (commentsList is List) {
      for (final c in commentsList) {
        if (c is Map<String, dynamic>) {
          comments.add(c);
        }
      }
    }

    for (final fn in functionNodes) {
      final cc = _computeCyclomaticComplexity(fn);
      if (cc >= minCC) {
        final hasIntent = _hasIntentComment(fn, comments);
        if (!hasIntent) {
          final fnName = _getFunctionName(fn, root);
          findings.add(
            Finding(
              ruleId: id,
              ruleName: name,
              severity: severity,
              filePath: filePath,
              line: fn.line,
              message: 'Function "$fnName" has complexity $cc but no intent '
                  'documentation (no comments explaining why).',
              evidence: {
                'cyclomatic_complexity': '$cc',
                'intent_comments': '0',
              },
            ),
          );
        }
      }
    }

    return findings;
  }

  bool _hasIntentComment(TsNode fnNode, List<Map<String, dynamic>> comments) {
    const intentKeywords = {
      'why', 'because', 'reason', 'purpose', 'intent',
      'rationale', 'note', 'important', 'hack', 'workaround', 'todo'
    };

    for (final comment in comments) {
      final start = comment['start'] is int ? comment['start'] as int : 0;
      final end = comment['end'] is int ? comment['end'] as int : 0;
      final value = comment['value']?.toString() ?? '';

      // Preceding comment: within 200 characters before the function starts
      final isPreceding = end <= fnNode.start && end >= fnNode.start - 200;
      // Inline comment: inside the function range
      final isInline = start >= fnNode.start && end <= fnNode.end;

      if (isPreceding || isInline) {
        final lower = value.toLowerCase();
        for (final kw in intentKeywords) {
          if (lower.contains(kw)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  int _computeCyclomaticComplexity(TsNode fnNode) {
    var decisionPoints = 0;

    void count(TsNode node) {
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
