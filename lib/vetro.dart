/// Vetro — AI Code Debt Scanner.
///
/// Detects technical debt patterns specific to AI-generated code
/// using deterministic mathematical analysis on Abstract Syntax Trees.
///
/// Core principle: **Math proves. AI opines.**
library;

export 'analyzers/dart/dart_analyzer.dart';
export 'analyzers/typescript/typescript_analyzer.dart';
export 'core/metrics/complexity.dart';
export 'core/metrics/entropy.dart';
export 'core/metrics/similarity.dart';
export 'core/models/config.dart';
export 'core/models/finding.dart';
export 'core/models/ts_node.dart';
export 'core/report/json_reporter.dart';
export 'core/report/markdown_reporter.dart';
export 'core/report/reporter.dart';
export 'core/report/terminal_reporter.dart';
export 'core/rules/rule.dart';
export 'core/rules/rule_registry.dart';
