/// Rule: Cyclomatic Complexity — flags functions with high branch complexity.
///
/// **Mathematical basis**: McCabe's cyclomatic complexity
/// CC = 1 + Σ(decision points in the control flow graph).
///
/// Decision points: `if`, `for`, `while`, `do`, `switch case`,
/// `catch`, `&&`, `||`, `?.`, `??`, ternary `? :`.
///
/// Functions with CC above a configurable threshold (default: 15)
/// produce a finding. High CC correlates with AI-generated code that
/// handles every edge case inline instead of decomposing.
library;

import 'package:analyzer/dart/ast/ast.dart';

import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/analyzers/dart/adapters/dart_complexity.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Detects functions and methods whose cyclomatic complexity exceeds
/// a configurable threshold.
///
/// **Threshold**: `max_complexity` (default 15).
///
/// Evidence includes the computed CC value for reproducibility.
final class CyclomaticComplexityRule extends Rule {
  /// Creates a [CyclomaticComplexityRule] with the given [config].
  const CyclomaticComplexityRule({required super.config});

  @override
  String get id => 'cyclomatic_complexity';

  @override
  String get name => 'Cyclomatic Complexity';

  @override
  String get description =>
      'Flags functions whose cyclomatic complexity exceeds the threshold.';

  @override
  List<Finding> analyze(
    CompilationUnit unit,
    String filePath,
    String source,
  ) {
    final maxCC =
        config.threshold('max_complexity', defaultValue: 15.0).toInt();
    final findings = <Finding>[];

    // We extract both functions and methods because both can contain 
    // branching control flow logic that contributes to cyclomatic complexity.
    for (final decl in extractDeclarations(unit)) {
      if (decl.body case final body?) {
        final cc = cyclomaticComplexity(body);
        if (cc > maxCC) {
          findings.add(
            _buildFinding(
              filePath: filePath,
              unit: unit,
              node: decl.node,
              name: decl.name,
              cc: cc,
              maxCC: maxCC,
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
    required int cc,
    required int maxCC,
  }) {
    final line = unit.lineInfo.getLocation(node.offset).lineNumber;
    return Finding(
      ruleId: id,
      ruleName: this.name,
      severity: severity,
      filePath: filePath,
      line: line,
      message: 'Function "$name" has cyclomatic complexity $cc '
          '(threshold: $maxCC).',
      evidence: {
        'cyclomatic_complexity': '$cc',
        'threshold': '$maxCC',
      },
    );
  }
}
