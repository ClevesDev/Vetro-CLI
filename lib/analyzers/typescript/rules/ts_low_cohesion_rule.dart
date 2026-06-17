import 'dart:math' as math;
import 'package:vetro/analyzers/typescript/rules/ts_rule.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/ts_node.dart';

/// Rule: Low Cohesion for TypeScript.
///
/// Flags TypeScript classes whose average method identifier cosine similarity falls below the threshold.
final class TsLowCohesionRule extends TsRule {
  const TsLowCohesionRule({required super.config});

  @override
  String get id => 'low_cohesion';

  @override
  String get name => 'Low Cohesion (TS)';

  @override
  String get description =>
      'Flags classes whose average method identifier cosine similarity falls below the threshold.';

  @override
  List<Finding> analyze(
    TsNode root,
    String filePath,
    String source,
  ) {
    final minCohesion =
        config.threshold('min_cohesion', defaultValue: 0.15);
    final minMethods =
        config.threshold('min_methods', defaultValue: 3.0).toInt();
    final findings = <Finding>[];

    // Find all class declarations/expressions.
    final classNodes = root.descendentNodes((node) =>
        node.type == 'ClassDeclaration' || node.type == 'ClassExpression');

    for (final cls in classNodes) {
      final isAbstract = cls.raw['abstract'] == true;
      if (isAbstract) continue;

      // Extract all non-constructor methods.
      final classBody = cls.children.firstWhere(
        (c) => c.type == 'ClassBody',
        orElse: () => cls,
      );

      final methods = classBody.children.where((c) =>
          c.type == 'ClassMethod' && c.raw['kind'] != 'constructor').toList();

      if (methods.length >= minMethods) {
        final cohesion = _computeClassCohesion(methods);
        if (cohesion < minCohesion) {
          final className = _getClassName(cls);
          findings.add(
            Finding(
              ruleId: id,
              ruleName: name,
              severity: severity,
              filePath: filePath,
              line: cls.line,
              message: 'Class "$className" has low cohesion: '
                  '${(cohesion * 100).toStringAsFixed(1)}% '
                  '(threshold: ${(minCohesion * 100).toStringAsFixed(1)}%).',
              evidence: {
                'semantic_cohesion': '${(cohesion * 100).toStringAsFixed(1)}%',
                'threshold': '${(minCohesion * 100).toStringAsFixed(1)}%',
              },
            ),
          );
        }
      }
    }

    return findings;
  }

  double _computeClassCohesion(List<TsNode> methods) {
    if (methods.length <= 1) return 1.0;

    final vocabularies = <Set<String>>[];
    for (final method in methods) {
      vocabularies.add(_extractMethodIdentifiers(method));
    }

    var sumSimilarity = 0.0;
    var countPairs = 0;

    for (var i = 0; i < vocabularies.length; i++) {
      for (var j = i + 1; j < vocabularies.length; j++) {
        final vocabA = vocabularies[i];
        final vocabB = vocabularies[j];

        if (vocabA.isEmpty || vocabB.isEmpty) {
          continue;
        }

        final intersectionSize = vocabA.intersection(vocabB).length;
        final denominator = math.sqrt(vocabA.length * vocabB.length);

        final similarity = denominator == 0 ? 0.0 : intersectionSize / denominator;
        sumSimilarity += similarity;
        countPairs++;
      }
    }

    if (countPairs == 0) return 1.0;
    return sumSimilarity / countPairs;
  }

  Set<String> _extractMethodIdentifiers(TsNode methodNode) {
    final identifiers = <String>{};
    const stopWords = {
      'void', 'int', 'double', 'num', 'String', 'bool', 'List', 'Map', 'Set',
      'dynamic', 'var', 'final', 'const', 'true', 'false', 'null', 'any', 'string',
      'number', 'boolean', 'this', 'super', 'constructor', 'undefined'
    };

    void collect(TsNode n) {
      if (n.type == 'Identifier') {
        final name = n.raw['name']?.toString();
        if (name != null && name.isNotEmpty && !stopWords.contains(name)) {
          identifiers.add(name);
        }
      }
      for (final child in n.children) {
        collect(child);
      }
    }

    collect(methodNode);
    return identifiers;
  }

  String _getClassName(TsNode classNode) {
    final idMap = classNode.raw['id'];
    if (idMap is Map && idMap['name'] != null) {
      return idMap['name'].toString();
    }
    return 'anonymous';
  }
}
