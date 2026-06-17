import 'package:analyzer/dart/ast/ast.dart';
import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/metrics/entropy.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Rule: Low Entropy — flags functions with low informational variety of AST node types.
final class LowEntropyRule extends Rule {
  const LowEntropyRule({required super.config});

  @override
  String get id => 'low_entropy';

  @override
  String get name => 'Low Entropy';

  @override
  String get description =>
      'Flags complex or long functions whose AST node type entropy is abnormally low.';

  @override
  List<Finding> analyze(
    CompilationUnit unit,
    String filePath,
    String source,
  ) {
    // Note: The purpose of this rule is to detect highly repetitive boilerplate or flat structures.
    final minEntropy =
        config.threshold('min_entropy', defaultValue: 1.8);
    final minIdentEntropy =
        config.threshold('min_identifier_entropy', defaultValue: 2.0);
    final minNodes =
        config.threshold('min_nodes', defaultValue: 30.0).toInt();
    final findings = <Finding>[];

    for (final decl in extractDeclarations(unit)) {
      if (decl.body case final body?) {
        final totalNodes = nodeCount(body);
        if (totalNodes >= minNodes) {
          final h = shannonEntropy(body);
          if (h < minEntropy) {
            findings.add(
              _buildFinding(
                filePath: filePath,
                unit: unit,
                node: decl.node,
                name: decl.name,
                entropy: h,
                totalNodes: totalNodes,
                minEntropy: minEntropy,
              ),
            );
          } else {
            final hIdent = identifierEntropy(body);
            if (hIdent < minIdentEntropy) {
              findings.add(
                _buildIdentifierFinding(
                  filePath: filePath,
                  unit: unit,
                  node: decl.node,
                  name: decl.name,
                  entropy: hIdent,
                  totalNodes: totalNodes,
                  minEntropy: minIdentEntropy,
                ),
              );
            }
          }
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
    required double entropy,
    required int totalNodes,
    required double minEntropy,
  }) {
    final line = unit.lineInfo.getLocation(node.offset).lineNumber;
    return Finding(
      ruleId: id,
      ruleName: this.name,
      severity: severity,
      filePath: filePath,
      line: line,
      message: 'Function "$name" has Shannon entropy ${entropy.toStringAsFixed(3)} '
          'with $totalNodes nodes (threshold: ${minEntropy.toStringAsFixed(3)}).',
      evidence: {
        'shannon_entropy': entropy.toStringAsFixed(3),
        'node_count': '$totalNodes',
        'threshold': minEntropy.toStringAsFixed(3),
      },
    );
  }

  Finding _buildIdentifierFinding({
    required String filePath,
    required CompilationUnit unit,
    required AstNode node,
    required String name,
    required double entropy,
    required int totalNodes,
    required double minEntropy,
  }) {
    final line = unit.lineInfo.getLocation(node.offset).lineNumber;
    return Finding(
      ruleId: id,
      ruleName: this.name,
      severity: severity,
      filePath: filePath,
      line: line,
      message: 'Function "$name" has low identifier Shannon entropy ${entropy.toStringAsFixed(3)} '
          'with $totalNodes nodes (threshold: ${minEntropy.toStringAsFixed(3)}).',
      evidence: {
        'identifier_entropy': entropy.toStringAsFixed(3),
        'node_count': '$totalNodes',
        'threshold': minEntropy.toStringAsFixed(3),
      },
    );
  }
}
