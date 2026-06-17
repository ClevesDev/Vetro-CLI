import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Rule: Low Entropy — flags functions with low informational variety of AST node types or identifiers.
final class LowEntropyRule extends AnalysisRule {
  const LowEntropyRule({required super.config});

  @override
  String get id => 'low_entropy';

  @override
  String get name => 'Low Entropy';

  @override
  String get description =>
      'Flags complex or long functions whose AST node type entropy is abnormally low.';

  @override
  List<Finding> analyzeFile(FileContext context) {
    // Note: We retrieve thresholds from configuration.
    // This is important because different languages and projects have different entropy baselines.
    final minEntropy =
        config.threshold('min_entropy', defaultValue: 1.8);
    final minIdentEntropy =
        config.threshold('min_identifier_entropy', defaultValue: 2.0);
    final minNodes =
        config.threshold('min_nodes', defaultValue: 30.0).toInt();
    final findings = <Finding>[];

    // Note: We use forEachFunction because it abstracts function/method traversal
    // and prevents copy-paste loop debt across unified rules.
    forEachFunction(context, (fn) {
      if (fn.nodeCount >= minNodes) {
        if (fn.shannonEntropy < minEntropy) {
          findings.add(
            _buildFinding(
              filePath: context.filePath,
              fn: fn,
              entropy: fn.shannonEntropy,
              minEntropy: minEntropy,
            ),
          );
        } else if (fn.identifierEntropy < minIdentEntropy) {
          findings.add(
            _buildIdentifierFinding(
              filePath: context.filePath,
              fn: fn,
              entropy: fn.identifierEntropy,
              minEntropy: minIdentEntropy,
            ),
          );
        }
      }
    });

    return findings;
  }

  Finding _buildFinding({
    required String filePath,
    required FunctionContext fn,
    required double entropy,
    required double minEntropy,
  }) {
    return Finding(
      ruleId: id,
      ruleName: name,
      severity: severity,
      filePath: filePath,
      line: fn.startLine,
      message: 'Function "${fn.name}" has low AST node Shannon entropy '
          '${entropy.toStringAsFixed(3)} with ${fn.nodeCount} nodes (threshold: ${minEntropy.toStringAsFixed(3)}).',
      evidence: {
        'shannon_entropy': entropy.toStringAsFixed(3),
        'node_count': '${fn.nodeCount}',
        'threshold': minEntropy.toStringAsFixed(3),
      },
    );
  }

  Finding _buildIdentifierFinding({
    required String filePath,
    required FunctionContext fn,
    required double entropy,
    required double minEntropy,
  }) {
    return Finding(
      ruleId: id,
      ruleName: name,
      severity: severity,
      filePath: filePath,
      line: fn.startLine,
      message: 'Function "${fn.name}" has low identifier Shannon entropy '
          '${entropy.toStringAsFixed(3)} with ${fn.nodeCount} nodes (threshold: ${minEntropy.toStringAsFixed(3)}).',
      evidence: {
        'identifier_entropy': entropy.toStringAsFixed(3),
        'node_count': '${fn.nodeCount}',
        'threshold': minEntropy.toStringAsFixed(3),
      },
    );
  }
}
