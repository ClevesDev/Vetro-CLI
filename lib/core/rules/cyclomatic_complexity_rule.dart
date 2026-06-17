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
    final maxCC =
        config.threshold('max_complexity', defaultValue: 15.0).toInt();
    final findings = <Finding>[];

    // Check top-level functions
    for (final fn in context.functions) {
      if (fn.cyclomaticComplexity > maxCC) {
        findings.add(
          _buildFinding(context.filePath, fn, maxCC),
        );
      }
    }

    // Check class methods
    for (final cl in context.classes) {
      for (final fn in cl.methods) {
        if (fn.cyclomaticComplexity > maxCC) {
          findings.add(
            _buildFinding(context.filePath, fn, maxCC),
          );
        }
      }
    }

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
