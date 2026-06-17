/// Rule: Cognitive Complexity — flags functions with high cognitive complexity.
///
/// **Mathematical basis**: Campbell's Cognitive Complexity.
/// Penalizes nested control structures recursively.
library;

import 'package:analyzer/dart/ast/ast.dart';

import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/adapters/dart/dart_complexity.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Detects functions and methods whose cognitive complexity exceeds
/// a configurable threshold.
///
/// **Threshold**: `max_cognitive_complexity` (default 15).
final class CognitiveComplexityRule extends Rule {
  /// Creates a [CognitiveComplexityRule] with the given [config].
  const CognitiveComplexityRule({required super.config});

  @override
  String get id => 'cognitive_complexity';

  @override
  String get name => 'Cognitive Complexity';

  @override
  String get description =>
      'Flags functions whose cognitive complexity exceeds the threshold.';

  @override
  List<Finding> analyze(
    CompilationUnit unit,
    String filePath,
    String source,
  ) {
    final maxComplexity =
        config.threshold('max_cognitive_complexity', defaultValue: 15.0).toInt();
    final findings = <Finding>[];

    for (final decl in extractDeclarations(unit)) {
      if (decl.body case final body?) {
        final comp = cognitiveComplexity(body);
        if (comp > maxComplexity) {
          findings.add(
            _buildFinding(
              filePath: filePath,
              unit: unit,
              node: decl.node,
              name: decl.name,
              complexity: comp,
              maxComplexity: maxComplexity,
            ),
          );
        }
      }
    }

    return findings;
  }

  Finding _buildFinding({
    required String filePath,
    required CompilationUnit unit,
    required AstNode node,
    required String name,
    required int complexity,
    required int maxComplexity,
  }) {
    final line = unit.lineInfo.getLocation(node.offset).lineNumber;
    return Finding(
      ruleId: id,
      ruleName: this.name,
      severity: severity,
      filePath: filePath,
      line: line,
      message: 'Function "$name" has cognitive complexity $complexity '
          '(threshold: $maxComplexity).',
      evidence: {
        'cognitive_complexity': '$complexity',
        'threshold': '$maxComplexity',
      },
    );
  }
}
