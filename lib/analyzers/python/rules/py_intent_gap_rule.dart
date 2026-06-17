import 'package:vetro/analyzers/python/rules/py_rule.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/py_node.dart';

final class PyIntentGapRule extends PyRule {
  const PyIntentGapRule({required super.config});

  @override
  String get id => 'intent_gap';

  @override
  String get name => 'Intent Gap (Python)';

  @override
  String get description => 'Legacy Intent Gap placeholder for Python.';

  @override
  List<Finding> analyze(PyNode root, String filePath, String source) => const [];
}
