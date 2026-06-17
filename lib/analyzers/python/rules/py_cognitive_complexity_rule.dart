import 'package:vetro/analyzers/python/rules/py_rule.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/py_node.dart';
import 'package:vetro/analyzers/python/adapters/python_adapter.dart';

/// Rule: Cognitive Complexity for Python.
final class PyCognitiveComplexityRule extends PyRule {
  const PyCognitiveComplexityRule({required super.config});

  @override
  String get id => 'cognitive_complexity';

  @override
  String get name => 'Cognitive Complexity (Python)';

  @override
  String get description =>
      'Flags Python functions whose cognitive complexity exceeds the threshold.';

  @override
  List<Finding> analyze(
    PyNode root,
    String filePath,
    String source,
  ) {
    final maxCognitive =
        config.threshold('max_cognitive_complexity', defaultValue: 15.0).toInt();
    final findings = <Finding>[];

    final functionNodes = root.descendentNodes((node) => const {
          'FunctionDef',
          'AsyncFunctionDef',
        }.contains(node.type));

    final adapter = PythonAdapter(allFiles: {});

    for (final fn in functionNodes) {
      // We can reuse the adapter's implementation
      final context = adapter.adapt(root, filePath, source);
      final fnContext = context.functions.firstWhere(
        (f) => f.name == fn.raw['name'] || f.startLine == fn.line,
        orElse: () => context.classes
            .expand((c) => c.methods)
            .firstWhere((f) => f.name.endsWith('.${fn.raw['name']}') || f.startLine == fn.line),
      );

      final cc = fnContext.cognitiveComplexity;
      if (cc > maxCognitive) {
        final fnName = fn.raw['name']?.toString() ?? 'anonymous';
        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: filePath,
            line: fn.line,
            message: 'Function "$fnName" has cognitive complexity $cc '
                '(threshold: $maxCognitive).',
            evidence: {
              'cognitive_complexity': '$cc',
              'threshold': '$maxCognitive',
            },
          ),
        );
      }
    }

    return findings;
  }
}
