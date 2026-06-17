import 'dart:math' as math;
import 'package:vetro/analyzers/python/rules/py_rule.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/py_node.dart';

/// Rule: Low Cohesion for Python.
final class PyLowCohesionRule extends PyRule {
  const PyLowCohesionRule({required super.config});

  @override
  String get id => 'low_cohesion';

  @override
  String get name => 'Low Cohesion (Python)';

  @override
  String get description =>
      'Flags classes whose average method identifier cosine similarity falls below the threshold.';

  @override
  List<Finding> analyze(
    PyNode root,
    String filePath,
    String source,
  ) {
    final minCohesion =
        config.threshold('min_cohesion', defaultValue: 0.15);
    final minMethods =
        config.threshold('min_methods', defaultValue: 3.0).toInt();
    final findings = <Finding>[];

    final classNodes = root.descendentNodes((node) => node.type == 'ClassDef');

    for (final cls in classNodes) {
      // Extract all methods
      final methods = cls.descendentNodes((node) => const {
            'FunctionDef',
            'AsyncFunctionDef',
          }.contains(node.type));

      // Filter out double underscore internal methods except __init__ if needed, or analyze all.
      // In Python, it is standard to analyze all defined methods.
      if (methods.length >= minMethods) {
        final cohesion = _computeClassCohesion(methods);
        if (cohesion < minCohesion) {
          final className = cls.raw['name']?.toString() ?? 'anonymous';
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

  double _computeClassCohesion(List<PyNode> methods) {
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

  Set<String> _extractMethodIdentifiers(PyNode methodNode) {
    final identifiers = <String>{};
    const stopWords = {
      'False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await',
      'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except',
      'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is', 'lambda',
      'nonlocal', 'not', 'or', 'pass', 'raise', 'return', 'try', 'while',
      'with', 'yield', 'self', 'cls'
    };

    void collect(PyNode n) {
      if (n.type == 'Name') {
        final id = n.raw['id']?.toString();
        if (id != null && id.isNotEmpty && !stopWords.contains(id)) {
          identifiers.add(id);
        }
      } else if (n.type == 'arg') {
        final name = n.raw['arg']?.toString();
        if (name != null && name.isNotEmpty && !stopWords.contains(name)) {
          identifiers.add(name);
        }
      } else if (n.type == 'Attribute') {
        final attr = n.raw['attr']?.toString();
        if (attr != null && attr.isNotEmpty && !stopWords.contains(attr)) {
          identifiers.add(attr);
        }
      }
      for (final child in n.children) {
        collect(child);
      }
    }

    collect(methodNode);
    return identifiers;
  }
}
