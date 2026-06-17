import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Rule: Halstead Complexity — flags functions with high software effort.
final class HalsteadComplexityRule extends AnalysisRule {
  const HalsteadComplexityRule({required super.config});

  @override
  String get id => 'halstead_complexity';

  @override
  String get name => 'Halstead Complexity';

  @override
  String get description =>
      'Flags functions whose Halstead volume or effort exceeds thresholds.';

  @override
  List<Finding> analyzeFile(FileContext context) {
    // Note: We read the max effort threshold from configuration.
    // This is important because we want to flag code requiring high cognitive effort.
    final maxEffort = config.threshold('max_effort', defaultValue: 50000.0);
    final findings = <Finding>[];

    // Note: We use forEachFunction because it abstracts the traversal of both
    // top-level functions and class methods, preventing duplicated loops.
    forEachFunction(context, (fn) {
      if (fn.halsteadStats.effort > maxEffort) {
        findings.add(
          _buildFinding(context.filePath, fn, maxEffort),
        );
      }
    });

    return findings;
  }

  Finding _buildFinding(String filePath, FunctionContext fn, double maxEffort) {
    final stats = fn.halsteadStats;
    return Finding(
      ruleId: id,
      ruleName: name,
      severity: severity,
      filePath: filePath,
      line: fn.startLine,
      message: 'Function "${fn.name}" has Halstead effort ${stats.effort.toStringAsFixed(1)} '
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
