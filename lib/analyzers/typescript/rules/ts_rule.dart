import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/ts_node.dart';

/// Base contract for all TypeScript analysis rules.
abstract class TsRule {
  const TsRule({required this.config});

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

  /// Analyze a single file's TypeScript AST and return findings.
  List<Finding> analyze(
    TsNode root,
    String filePath,
    String source,
  );
}

/// A TypeScript rule that needs cross-file context to operate.
abstract class TsCrossFileRule extends TsRule {
  const TsCrossFileRule({required super.config});

  /// Analyze the entire project and return findings.
  Future<List<Finding>> analyzeProject(
    Map<String, TsNode> roots,
    Map<String, String> sources,
  );

  @override
  List<Finding> analyze(
    TsNode root,
    String filePath,
    String source,
  ) =>
      const [];
}
