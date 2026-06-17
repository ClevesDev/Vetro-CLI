import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/py_node.dart';

/// Base contract for all Python analysis rules.
abstract class PyRule {
  const PyRule({required this.config});

  /// Unique identifier for this rule (snake_case).
  String get id;

  /// Human-readable name for display.
  String get name;

  /// Brief description of what this rule detects.
  String get description;

  /// Configuration for this rule (severity, thresholds).
  final RuleConfig config;

  /// The effective severity for findings from this rule.
  Severity get severity => config.severity;

  /// Analyze a single file's Python AST and return findings.
  List<Finding> analyze(
    PyNode root,
    String filePath,
    String source,
  );
}

/// A Python rule that needs cross-file context to operate.
abstract class PyCrossFileRule extends PyRule {
  const PyCrossFileRule({required super.config});

  /// Analyze the entire project and return findings.
  Future<List<Finding>> analyzeProject(
    Map<String, PyNode> roots,
    Map<String, String> sources,
  );

  @override
  List<Finding> analyze(
    PyNode root,
    String filePath,
    String source,
  ) =>
      const [];
}
