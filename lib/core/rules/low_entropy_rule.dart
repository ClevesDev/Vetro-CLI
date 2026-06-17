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
    final minEntropy =
        config.threshold('min_entropy', defaultValue: 1.8);
    final minIdentEntropy =
        config.threshold('min_identifier_entropy', defaultValue: 2.0);
    final minNodes =
        config.threshold('min_nodes', defaultValue: 30.0).toInt();
    final findings = <Finding>[];

    // Check top-level functions
    for (final fn in context.functions) {
      _checkFunction(context.filePath, fn, minNodes, minEntropy, minIdentEntropy, findings);
    }

    // Check class methods
    for (final cl in context.classes) {
      for (final fn in cl.methods) {
        _checkFunction(context.filePath, fn, minNodes, minEntropy, minIdentEntropy, findings);
      }
    }

    return findings;
  }

  void _checkFunction(
    String filePath,
    FunctionContext fn,
    int minNodes,
    double minEntropy,
    double minIdentEntropy,
    List<Finding> findings,
  ) {
    if (fn.nodeCount >= minNodes) {
      if (fn.shannonEntropy < minEntropy) {
        findings.add(
          _buildFinding(
            filePath: filePath,
            fn: fn,
            entropy: fn.shannonEntropy,
            minEntropy: minEntropy,
          ),
        );
      } else if (fn.identifierEntropy < minIdentEntropy) {
        findings.add(
          _buildIdentifierFinding(
            filePath: filePath,
            fn: fn,
            entropy: fn.identifierEntropy,
            minEntropy: minIdentEntropy,
          ),
        );
      }
    }
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
      message: 'Function "${fn.name}" has Shannon entropy ${entropy.toStringAsFixed(3)} '
          'with ${fn.nodeCount} nodes (threshold: ${minEntropy.toStringAsFixed(3)}).',
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
      message: 'Function "${fn.name}" has low identifier Shannon entropy ${entropy.toStringAsFixed(3)} '
          'with ${fn.nodeCount} nodes (threshold: ${minEntropy.toStringAsFixed(3)}).',
      evidence: {
        'identifier_entropy': entropy.toStringAsFixed(3),
        'node_count': '${fn.nodeCount}',
        'threshold': minEntropy.toStringAsFixed(3),
      },
    );
  }
}
