import 'package:vetro/analyzers/python/rules/py_rule.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/py_node.dart';

final class PyCyclomaticComplexityRule extends PyRule {
  const PyCyclomaticComplexityRule({required super.config});

  @override
  String get id => 'cyclomatic_complexity';

  @override
  String get name => 'Cyclomatic Complexity (Python)';

  @override
  String get description => 'Legacy Cyclomatic Complexity placeholder for Python.';

  @override
  List<Finding> analyze(PyNode root, String filePath, String source) => const [];
}
