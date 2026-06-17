import 'package:analyzer/dart/ast/ast.dart';
import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/metrics/halstead.dart';
import 'package:vetro/core/adapters/dart/dart_halstead.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Rule: Halstead Complexity — flags functions with high software effort.
final class HalsteadComplexityRule extends Rule {
  const HalsteadComplexityRule({required super.config});

  @override
  String get id => 'halstead_complexity';

  @override
  String get name => 'Halstead Complexity';

  @override
  String get description =>
      'Flags functions whose Halstead volume or effort exceeds thresholds.';

  @override
  List<Finding> analyze(
    CompilationUnit unit,
    String filePath,
    String source,
  ) {
    // Note: The purpose of this rule is to detect functions requiring high cognitive load.
    final maxEffort =
        config.threshold('max_effort', defaultValue: 50000.0);
    final findings = <Finding>[];

    for (final decl in extractDeclarations(unit)) {
      if (decl.body case final body?) {
        final stats = halsteadMetrics(body);
        if (stats.effort > maxEffort) {
          findings.add(
            _buildFinding(
              filePath: filePath,
              unit: unit,
              node: decl.node,
              name: decl.name,
              stats: stats,
              maxEffort: maxEffort,
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
    required HalsteadStats stats,
    required double maxEffort,
  }) {
    final line = unit.lineInfo.getLocation(node.offset).lineNumber;
    return Finding(
      ruleId: id,
      ruleName: this.name,
      severity: severity,
      filePath: filePath,
      line: line,
      message: 'Function "$name" has Halstead effort ${stats.effort.toStringAsFixed(1)} '
          '(threshold: ${maxEffort.toStringAsFixed(1)}).',
      evidence: {
        'halstead_effort': stats.effort.toStringAsFixed(1),
        'halstead_volume': stats.volume.toStringAsFixed(1),
        'halstead_difficulty': stats.difficulty.toStringAsFixed(1),
        'distinct_operators': '${stats.distinctOperators}',
        'distinct_operands': '${stats.distinctOperands}',
        'threshold': maxEffort.toStringAsFixed(1),
      },
    );
  }
}
