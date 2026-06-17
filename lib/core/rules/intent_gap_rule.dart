import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Rule: Intent Gap — detects complex functions lacking intent documentation.
final class IntentGapRule extends AnalysisRule {
  const IntentGapRule({required super.config});

  @override
  String get id => 'intent_gap';

  @override
  String get name => 'Intent Gap';

  @override
  String get description =>
      'Flags complex functions that lack intent documentation (comments explaining why).';

  @override
  List<Finding> analyzeFile(FileContext context) {
    // Note: We retrieve the minimum complexity threshold to qualify for checking.
    // This is important because simple helper functions do not need detailed intent comments.
    final minCC =
        config.threshold('min_complexity', defaultValue: 5.0).toInt();
    final findings = <Finding>[];

    // Note: We use forEachFunction because it abstracts function/method traversal
    // and prevents copy-paste loop debt across unified rules.
    forEachFunction(context, (fn) {
      if (fn.cyclomaticComplexity >= minCC && fn.commentIntentRatio == 0.0) {
        findings.add(_buildFinding(context.filePath, fn, fn.cyclomaticComplexity));
      }
    });

    return findings;
  }

  Finding _buildFinding(String filePath, FunctionContext fn, int cc) {
    return Finding(
      ruleId: id,
      ruleName: name,
      severity: severity,
      filePath: filePath,
      line: fn.startLine,
      message: 'Function "${fn.name}" has complexity $cc but no intent '
          'documentation (no comments explaining why).',
      evidence: {
        'cyclomatic_complexity': '$cc',
        'intent_comments': '0',
      },
    );
  }
}
