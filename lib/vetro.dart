/// Vetro — AI Code Debt Scanner.
///
/// Detects technical debt patterns specific to AI-generated code
/// using deterministic mathematical analysis on Abstract Syntax Trees.
///
/// Core principle: **Math proves. AI opines.**
library;

export 'analyzers/dart/dart_analyzer.dart';
export 'analyzers/typescript/typescript_analyzer.dart';
export 'analyzers/python/python_analyzer.dart';
export 'core/models/py_node.dart';
export 'analyzers/dart/adapters/dart_complexity.dart';
export 'analyzers/dart/adapters/dart_similarity.dart';
export 'analyzers/dart/adapters/dart_entropy.dart';
export 'analyzers/dart/adapters/dart_halstead.dart';
export 'analyzers/dart/adapters/dart_cohesion.dart';
export 'core/metrics/entropy.dart';
export 'core/metrics/halstead.dart';
export 'core/metrics/similarity.dart';
export 'core/models/config.dart';
export 'core/models/finding.dart';
export 'core/models/context.dart';
export 'core/models/base_analyzer.dart';
export 'core/models/ts_node.dart';
export 'core/report/json_reporter.dart';
export 'core/report/markdown_reporter.dart';
export 'core/report/reporter.dart';
export 'core/report/terminal_reporter.dart';
export 'core/rules/rule.dart';
export 'core/rules/rule_registry.dart';
export 'core/rules/cyclomatic_complexity_rule.dart';
export 'core/rules/low_entropy_rule.dart';
export 'core/rules/intent_gap_rule.dart';
