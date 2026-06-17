import 'package:analyzer/dart/ast/ast.dart';
import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/analyzers/dart/adapters/dart_cohesion.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Rule: Low Cohesion — flags classes with low semantic method vocabulary cohesion.
final class LowCohesionRule extends Rule {
  const LowCohesionRule({required super.config});

  @override
  String get id => 'low_cohesion';

  @override
  String get name => 'Low Cohesion';

  @override
  String get description =>
      'Flags classes whose average method identifier cosine similarity falls below the threshold.';

  @override
  List<Finding> analyze(
    CompilationUnit unit,
    String filePath,
    String source,
  ) {
    final minCohesion =
        config.threshold('min_cohesion', defaultValue: 0.15);
    final minMethods =
        config.threshold('min_methods', defaultValue: 3.0).toInt();
    final findings = <Finding>[];

    for (final cls in extractClasses(unit)) {
      if (cls.abstractKeyword == null &&
          cls.members.whereType<MethodDeclaration>().length >= minMethods) {
        final cohesion = classCohesion(cls);
        if (cohesion < minCohesion) {
          findings.add(
            _buildFinding(
              filePath: filePath,
              unit: unit,
              node: cls,
              name: cls.name.lexeme,
              cohesion: cohesion,
              minCohesion: minCohesion,
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
    required double cohesion,
    required double minCohesion,
  }) {
    final line = unit.lineInfo.getLocation(node.offset).lineNumber;
    return Finding(
      ruleId: id,
      ruleName: this.name,
      severity: severity,
      filePath: filePath,
      line: line,
      message: 'Class "$name" has low cohesion: '
          '${(cohesion * 100).toStringAsFixed(1)}% '
          '(threshold: ${(minCohesion * 100).toStringAsFixed(1)}%).',
      evidence: {
        'semantic_cohesion': '${(cohesion * 100).toStringAsFixed(1)}%',
        'threshold': '${(minCohesion * 100).toStringAsFixed(1)}%',
      },
    );
  }
}
