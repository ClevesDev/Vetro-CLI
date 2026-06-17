import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Rule: Cyclomatic Complexity — flags functions with high branch complexity.
final class CyclomaticComplexityRule extends AnalysisRule {
  const CyclomaticComplexityRule({required super.config});

  @override
  String get id => 'cyclomatic_complexity';

  @override
  String get name => 'Cyclomatic Complexity';

  @override
  String get description =>
      'Flags functions whose cyclomatic complexity exceeds the threshold.';

  @override
  List<Finding> analyzeFile(FileContext context) {
    // Note: We retrieve the threshold from configuration.
    // This is important because different teams have different tolerances for complexity.
    final maxCC =
        config.threshold('max_complexity', defaultValue: 15.0).toInt();
    final findings = <Finding>[];

    // Note: We use forEachFunction because it abstracts the traversal of both
    // top-level functions and class methods, which avoids copy-paste loop debt.
    forEachFunction(context, (fn) {
      if (fn.cyclomaticComplexity > maxCC) {
        findings.add(
          _buildFinding(context.filePath, fn, maxCC),
        );
      }
    });

    return findings;
  }

  Finding _buildFinding(String filePath, FunctionContext fn, int maxCC) {
    return Finding(
      ruleId: id,
      ruleName: name,
      severity: severity,
      filePath: filePath,
      line: fn.startLine,
      message: 'Function "${fn.name}" has cyclomatic complexity ${fn.cyclomaticComplexity} '
          '(threshold: $maxCC).',
      evidence: {
        'cyclomatic_complexity': '${fn.cyclomaticComplexity}',
        'threshold': '$maxCC',
      },
    );
  }
}
