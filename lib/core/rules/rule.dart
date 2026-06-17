/// Base contract for all Vetro analysis rules.
///
/// A Rule is a deterministic function: given the same AST input,
/// it ALWAYS produces the same findings. No randomness, no AI,
/// no network calls. Pure mathematical analysis.
library;

import 'package:analyzer/dart/ast/ast.dart';

import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';

/// A single analysis rule that inspects a Dart compilation unit
/// and produces zero or more [Finding]s.
///
/// Rules must be:
/// - **Deterministic**: Same input → same output, always.
/// - **Pure**: No side effects, no IO, no state mutation.
/// - **Measurable**: Every finding includes quantitative evidence.
abstract class Rule {
  const Rule({required this.config});

  /// Unique identifier for this rule (snake_case).
  /// Example: `'semantic_duplication'`
  String get id;

  /// Human-readable name for display.
  /// Example: `'Semantic Duplication'`
  String get name;

  /// Brief description of what this rule detects.
  String get description;

  /// Configuration for this rule (severity, thresholds).
  final RuleConfig config;

  /// The effective severity for findings from this rule.
  Severity get severity => config.severity;

  /// Analyze a single file's AST and return findings.
  ///
  /// [unit] is the parsed AST of the file.
  /// [filePath] is the absolute path to the file (for reporting).
  /// [source] is the raw source code of the file.
  List<Finding> analyze(
    CompilationUnit unit,
    String filePath,
    String source,
  );
}

/// A rule that needs cross-file context to operate.
///
/// Some rules (like semantic duplication) need to compare functions
/// across multiple files. These rules implement [analyzeProject]
/// instead of (or in addition to) [analyze].
abstract class CrossFileRule extends Rule {
  const CrossFileRule({required super.config});

  /// Analyze the entire project and return findings.
  ///
  /// [units] maps file paths to their parsed ASTs.
  /// [sources] maps file paths to their raw source code.
  Future<List<Finding>> analyzeProject(
    Map<String, CompilationUnit> units,
    Map<String, String> sources,
  );

  /// Single-file analysis — cross-file rules may return empty here
  /// and do all work in [analyzeProject].
  @override
  List<Finding> analyze(
    CompilationUnit unit,
    String filePath,
    String source,
  ) =>
      const [];
}

typedef ImportGraph = Map<String, List<String>>;

/// Unified, AST-agnostic contract for all Vetro rules.
abstract class AnalysisRule {
  const AnalysisRule({required this.config});

  /// Unique identifier for this rule (snake_case).
  String get id;

  /// Human-readable name.
  String get name;

  /// Brief description of what the rule detects.
  String get description;

  /// Configuration for this rule (severity, thresholds).
  final RuleConfig config;

  /// The effective severity for findings from this rule.
  Severity get severity => config.severity;

  /// Indicates if this rule needs project-wide/cross-file context.
  bool get isCrossFile => false;

  /// Analyzes a single file's context.
  List<Finding> analyzeFile(FileContext context);

  /// Analyzes the entire project context (only called if [isCrossFile] is true).
  Future<List<Finding>> analyzeProject(
    Map<String, FileContext> contexts,
    ImportGraph graph,
  ) async => const [];

  /// Helper to iterate through all top-level functions and class methods
  /// defined in the given [context].
  ///
  /// This utility is important because it prevents duplicate loop boilerplates
  /// across different analysis rules, reducing copy-mutate code debt.
  void forEachFunction(FileContext context, void Function(FunctionContext fn) action) {
    for (final fn in context.functions) {
      action(fn);
    }
    for (final cl in context.classes) {
      for (final fn in cl.methods) {
        action(fn);
      }
    }
  }
}
