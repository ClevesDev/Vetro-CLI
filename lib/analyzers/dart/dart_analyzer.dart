/// Dart analyzer orchestrator for Vetro.
///
/// Coordinates parsing, rule execution, and result aggregation for
/// a Dart project. Separates single-file [Rule]s from cross-file
/// [CrossFileRule]s and runs each appropriately.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

import 'package:vetro/analyzers/dart/ast_utils.dart' as ast_utils;
import 'package:vetro/analyzers/dart/rules/circular_dependency_rule.dart';
import 'package:vetro/analyzers/dart/rules/copy_mutate_rule.dart';
import 'package:vetro/analyzers/dart/rules/cyclomatic_complexity_rule.dart';
import 'package:vetro/analyzers/dart/rules/eigenvector_centrality_rule.dart';
import 'package:vetro/analyzers/dart/rules/fragile_test_rule.dart';
import 'package:vetro/analyzers/dart/rules/halstead_complexity_rule.dart';
import 'package:vetro/analyzers/dart/rules/intent_gap_rule.dart';
import 'package:vetro/analyzers/dart/rules/low_cohesion_rule.dart';
import 'package:vetro/analyzers/dart/rules/low_entropy_rule.dart';
import 'package:vetro/analyzers/dart/rules/orphaned_abstraction_rule.dart';
import 'package:vetro/analyzers/dart/rules/semantic_duplication_rule.dart';
import 'package:vetro/analyzers/dart/rules/boundary_violation_rule.dart';
import 'package:vetro/analyzers/dart/rules/cognitive_complexity_rule.dart';
import 'package:vetro/analyzers/dart/rules/local_clustering_coefficient_rule.dart';
import 'package:vetro/analyzers/dart/rules/tight_coupling_rule.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';
import 'package:vetro/core/rules/rule_registry.dart';

/// Analyzes Dart projects for AI-generated code debt.
///
/// Orchestrates file discovery, parsing, rule execution, and
/// result aggregation into a [ProjectReport].
///
/// Usage:
/// ```dart
/// final analyzer = DartAnalyzer();
/// final report = await analyzer.analyze('/path/to/project', config);
/// ```
final class DartAnalyzer {
  /// Creates a [DartAnalyzer] and registers all built-in rules.
  DartAnalyzer() {
    _registerBuiltInRules();
  }

  /// Registers all built-in Vetro rules with the [RuleRegistry].
  void _registerBuiltInRules() {
    final registry = RuleRegistry.instance;

    if (!registry.isRegistered('cyclomatic_complexity')) {
      registry.register(
        'cyclomatic_complexity',
        (config) => CyclomaticComplexityRule(config: config),
      );
    }
    if (!registry.isRegistered('intent_gap')) {
      registry.register(
        'intent_gap',
        (config) => IntentGapRule(config: config),
      );
    }
    if (!registry.isRegistered('orphaned_abstraction')) {
      registry.register(
        'orphaned_abstraction',
        (config) => OrphanedAbstractionRule(config: config),
      );
    }
    if (!registry.isRegistered('copy_mutate')) {
      registry.register(
        'copy_mutate',
        (config) => CopyMutateRule(config: config),
      );
    }
    if (!registry.isRegistered('semantic_duplication')) {
      registry.register(
        'semantic_duplication',
        (config) => SemanticDuplicationRule(config: config),
      );
    }
    if (!registry.isRegistered('fragile_test')) {
      registry.register(
        'fragile_test',
        (config) => FragileTestRule(config: config),
      );
    }
    if (!registry.isRegistered('circular_dependency')) {
      registry.register(
        'circular_dependency',
        (config) => CircularDependencyRule(config: config),
      );
    }
    if (!registry.isRegistered('tight_coupling')) {
      registry.register(
        'tight_coupling',
        (config) => TightCouplingRule(config: config),
      );
    }
    if (!registry.isRegistered('halstead_complexity')) {
      registry.register(
        'halstead_complexity',
        (config) => HalsteadComplexityRule(config: config),
      );
    }
    if (!registry.isRegistered('low_entropy')) {
      registry.register(
        'low_entropy',
        (config) => LowEntropyRule(config: config),
      );
    }
    if (!registry.isRegistered('eigenvector_centrality')) {
      registry.register(
        'eigenvector_centrality',
        (config) => EigenvectorCentralityRule(config: config),
      );
    }
    if (!registry.isRegistered('low_cohesion')) {
      registry.register(
        'low_cohesion',
        (config) => LowCohesionRule(config: config),
      );
    }
    if (!registry.isRegistered('boundary_violation')) {
      registry.register(
        'boundary_violation',
        (config) => BoundaryViolationRule(config: config),
      );
    }
    if (!registry.isRegistered('cognitive_complexity')) {
      registry.register(
        'cognitive_complexity',
        (config) => CognitiveComplexityRule(config: config),
      );
    }
    if (!registry.isRegistered('local_clustering_coefficient')) {
      registry.register(
        'local_clustering_coefficient',
        (config) => LocalClusteringCoefficientRule(config: config),
      );
    }
  }

  /// Analyzes a Dart project at [projectPath] using the given [config].
  ///
  /// 1. Discovers `.dart` files matching include/exclude globs
  /// 2. Parses each file into a [CompilationUnit]
  /// 3. Runs single-file [Rule]s against each file
  /// 4. Runs cross-file [CrossFileRule]s against all files
  /// 5. Aggregates results into per-file [FileReport]s and a [ProjectReport]
  ///
  /// Returns a [ProjectReport] with all findings and timing data.
  Future<ProjectReport> analyze(
    String projectPath,
    VetroConfig config,
  ) async {
    final stopwatch = Stopwatch()..start();

    // Step 1: Discover files.
    final files = await _discoverFiles(projectPath, config);

    // Step 2: Parse all files.
    final units = <String, CompilationUnit>{};
    final sources = <String, String>{};
    final parseErrors = <String, List<Finding>>{};

    for (final file in files) {
      final absolutePath = p.normalize(file.path);
      try {
        final source = await file.readAsString();
        if (config.autoExcludeGenerated && _isGeneratedCode(source)) {
          if (config.verbose) {
            print('Skipping auto-generated file: ${p.relative(absolutePath, from: projectPath)}');
          }
          continue;
        }
        sources[absolutePath] = source;
        final result = parseString(content: source);
        units[absolutePath] = result.unit;
      } catch (e) {
        final relativePath = p.relative(absolutePath, from: projectPath);
        parseErrors[absolutePath] = [
          Finding(
            ruleId: 'syntax_error',
            ruleName: 'Syntax Error',
            severity: Severity.error,
            filePath: absolutePath,
            line: 1,
            message: 'Failed to parse file "$relativePath" due to a syntax or compilation error: $e',
            evidence: {'error': e.toString()},
          )
        ];
        // If we failed to read or parse, still ensure a source entry exists
        // (even empty or partial) so we can generate a report for it.
        if (!sources.containsKey(absolutePath)) {
          sources[absolutePath] = '';
        }
      }
    }

    // Step 3: Create rules from config.
    final rules = RuleRegistry.instance.createRules(config);
    final singleFileRules = rules.whereType<Rule>().where(
      (r) => r is! CrossFileRule,
    ).toList();
    final crossFileRules = rules.whereType<CrossFileRule>().toList();

    // Step 4: Run single-file rules.
    final fileFindings = <String, List<Finding>>{};
    // Initialize with parse errors.
    fileFindings.addAll(parseErrors);

    for (final entry in units.entries) {
      final filePath = entry.key;
      final unit = entry.value;
      final source = sources[filePath]!;
      final findings = <Finding>[];

      for (final rule in singleFileRules) {
        findings.addAll(rule.analyze(unit, filePath, source));
      }

      fileFindings.putIfAbsent(filePath, () => <Finding>[]).addAll(findings);
    }

    // Step 5: Run cross-file rules.
    final crossFindings = <Finding>[];
    for (final rule in crossFileRules) {
      crossFindings.addAll(await rule.analyzeProject(units, sources));
    }

    // Merge cross-file findings into per-file buckets.
    for (final finding in crossFindings) {
      fileFindings
          .putIfAbsent(finding.filePath, () => <Finding>[])
          .add(finding);
    }

    // Step 6: Build FileReports.
    final fileReports = <FileReport>[];
    for (final entry in sources.entries) {
      final filePath = entry.key;
      final source = entry.value;
      final findings = fileFindings[filePath] ?? const [];

      fileReports.add(
        FileReport(
          filePath: filePath,
          findings: findings,
          lineCount: ast_utils.lineCount(source),
          analysisTimeMs: 0, // Individual timing not tracked.
        ),
      );
    }

    stopwatch.stop();

    return ProjectReport(
      projectPath: projectPath,
      fileReports: fileReports,
      totalAnalysisTimeMs: stopwatch.elapsedMilliseconds,
      analyzedAt: DateTime.now(),
    );
  }

  /// Discovers Dart files matching the include/exclude globs in [config].
  Future<List<File>> _discoverFiles(
    String projectPath,
    VetroConfig config,
  ) async {
    final included = <String>{};

    // Resolve include globs.
    for (final pattern in config.include) {
      final glob = Glob(pattern);
      await for (final entity in glob.list(root: projectPath)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          included.add(p.normalize(entity.path));
        }
      }
    }

    // Remove excluded files.
    final excludeGlobs = config.exclude.map(Glob.new).toList();
    final files = <File>[];
    for (final path in included) {
      final relativePath = p.relative(path, from: projectPath);
      final excluded = excludeGlobs.any(
        (glob) => glob.matches(relativePath),
      );
      if (!excluded) {
        files.add(File(path));
      }
    }

    // Sort for deterministic ordering.
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// Checks if the given source content is marked as autogenerated.
  bool _isGeneratedCode(String content) {
    // Check the first 2000 characters for common auto-generated headers
    final header = content.length > 2000 ? content.substring(0, 2000) : content;
    final lowercase = header.toLowerCase();
    return lowercase.contains('generated code - do not modify') ||
        lowercase.contains('generated by ffigen') ||
        lowercase.contains('package:ffigen') ||
        lowercase.contains('auto generated file') ||
        lowercase.contains('automatically generated') ||
        lowercase.contains('autogenerated by') ||
        lowercase.contains('generated code - do not edit') ||
        lowercase.contains('generated code - do not modify by hand');
  }
}
