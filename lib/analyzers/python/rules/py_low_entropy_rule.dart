import 'package:vetro/analyzers/python/rules/py_rule.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/py_node.dart';

final class PyLowEntropyRule extends PyRule {
  const PyLowEntropyRule({required super.config});

  @override
  String get id => 'low_entropy';

  @override
  String get name => 'Low Entropy (Python)';

  @override
  String get description => 'Legacy Low Entropy placeholder for Python.';

  @override
  List<Finding> analyze(PyNode root, String filePath, String source) => const [];
}
