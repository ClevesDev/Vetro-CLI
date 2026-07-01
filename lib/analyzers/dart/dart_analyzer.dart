/// Dart analyzer orchestrator for Vetro.
///
/// Coordinates parsing, rule execution, and result aggregation for
/// a Dart project.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:vetro/analyzers/dart/adapters/dart_adapter.dart';
import 'package:vetro/core/models/base_analyzer.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/project_context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';
import 'package:vetro/core/rules/rule_registry.dart';

// Import all legacy rules to register them
import 'package:vetro/analyzers/dart/rules/circular_dependency_rule.dart';
import 'package:vetro/analyzers/dart/rules/copy_mutate_rule.dart';
import 'package:vetro/analyzers/dart/rules/cyclomatic_complexity_rule.dart';
import 'package:vetro/analyzers/dart/rules/eigenvector_centrality_rule.dart';
import 'package:vetro/analyzers/dart/rules/fragile_test_rule.dart';
import 'package:vetro/analyzers/dart/rules/intent_gap_rule.dart';
import 'package:vetro/analyzers/dart/rules/low_cohesion_rule.dart';
import 'package:vetro/analyzers/dart/rules/low_entropy_rule.dart';
import 'package:vetro/analyzers/dart/rules/orphaned_abstraction_rule.dart';
import 'package:vetro/analyzers/dart/rules/semantic_duplication_rule.dart';
import 'package:vetro/analyzers/dart/rules/boundary_violation_rule.dart';
import 'package:vetro/analyzers/dart/rules/cognitive_complexity_rule.dart';
import 'package:vetro/analyzers/dart/rules/local_clustering_coefficient_rule.dart';
import 'package:vetro/analyzers/dart/rules/tight_coupling_rule.dart';
import 'package:vetro/analyzers/dart/rules/performance_media_query_rule.dart';
import 'package:vetro/analyzers/dart/rules/business_logic_in_ui_rule.dart';
import 'package:vetro/analyzers/dart/rules/misplaced_layout_constraints_rule.dart';
import 'package:vetro/analyzers/dart/rules/unreleased_controllers_rule.dart';
import 'package:vetro/analyzers/dart/rules/hardcoded_ui_tokens_rule.dart';
import 'package:vetro/analyzers/dart/rules/set_state_in_complex_builds_rule.dart';
import 'package:vetro/analyzers/dart/rules/missing_const_constructors_rule.dart';
import 'package:vetro/core/rules/cyclomatic_complexity_rule.dart' as core_rules;
import 'package:vetro/core/rules/low_entropy_rule.dart' as core_rules;
import 'package:vetro/core/rules/intent_gap_rule.dart' as core_rules;
import 'package:vetro/core/rules/halstead_complexity_rule.dart' as core_rules;

import 'ast_utils.dart' as ast_utils;

/// Analyzes Dart projects for AI-generated code debt.
final class DartAnalyzer extends BaseAnalyzer<CompilationUnit> {
  /// Creates a [DartAnalyzer] and registers all built-in rules.
  DartAnalyzer() {
    _registerBuiltInRules();
  }

  @override
  List<String> get supportedExtensions => const ['.dart'];

  @override
  Future<Map<String, CompilationUnit>> parseFiles(List<File> files, VetroConfig config) async {
    final parsed = <String, CompilationUnit>{};
    for (final file in files) {
      try {
        final source = await file.readAsString();
        final result = parseString(content: source);
        parsed[file.path] = result.unit;
      } catch (_) {
        // Handled as parse errors by BaseAnalyzer
      }
    }
    return parsed;
  }

  @override
  FileContext adaptToContext(CompilationUnit ast, String filePath, String source, ProjectContext projectContext) {
    const adapter = DartAdapter();
    return adapter.adapt(ast, filePath, source, projectContext);
  }



  @override
  List<AnalysisRule> loadRules(VetroConfig config) {
    final rules = <AnalysisRule>[];

    // Load new unified rules if enabled in the configuration
    final ccConfig = config.ruleConfig('cyclomatic_complexity');
    if (ccConfig.enabled) {
      rules.add(core_rules.CyclomaticComplexityRule(config: ccConfig));
    }
    final entropyConfig = config.ruleConfig('low_entropy');
    if (entropyConfig.enabled) {
      rules.add(core_rules.LowEntropyRule(config: entropyConfig));
    }
    final intentConfig = config.ruleConfig('intent_gap');
    if (intentConfig.enabled) {
      rules.add(core_rules.IntentGapRule(config: intentConfig));
    }
    final halsteadConfig = config.ruleConfig('halstead_complexity');
    if (halsteadConfig.enabled) {
      rules.add(core_rules.HalsteadComplexityRule(config: halsteadConfig));
    }

    // Load Flutter UI rules
    final mediaQueryConfig = config.ruleConfig('performance_media_query');
    if (mediaQueryConfig.enabled) {
      rules.add(PerformanceMediaQueryRule(config: mediaQueryConfig));
    }
    final businessLogicConfig = config.ruleConfig('business_logic_in_ui');
    if (businessLogicConfig.enabled) {
      rules.add(BusinessLogicInUiRule(config: businessLogicConfig));
    }
    final layoutConstraintsConfig = config.ruleConfig('misplaced_layout_constraints');
    if (layoutConstraintsConfig.enabled) {
      rules.add(MisplacedLayoutConstraintsRule(config: layoutConstraintsConfig));
    }
    final unreleasedControllersConfig = config.ruleConfig('unreleased_controllers');
    if (unreleasedControllersConfig.enabled) {
      rules.add(UnreleasedControllersRule(config: unreleasedControllersConfig));
    }
    final hardcodedUiTokensConfig = config.ruleConfig('hardcoded_ui_tokens');
    if (hardcodedUiTokensConfig.enabled) {
      rules.add(HardcodedUiTokensRule(config: hardcodedUiTokensConfig));
    }
    final setStateComplexConfig = config.ruleConfig('setState_in_complex_builds');
    if (setStateComplexConfig.enabled) {
      rules.add(SetStateInComplexBuildsRule(config: setStateComplexConfig));
    }
    final missingConstConfig = config.ruleConfig('missing_const_constructors');
    if (missingConstConfig.enabled) {
      rules.add(MissingConstConstructorsRule(config: missingConstConfig));
    }

    // Load remaining rules from the registry
    final legacyRules = RuleRegistry.instance.createRules(config);
    for (final rule in legacyRules) {
      if (rule.id == 'cyclomatic_complexity' ||
          rule.id == 'low_entropy' ||
          rule.id == 'intent_gap' ||
          rule.id == 'halstead_complexity' ||
          rule.id == 'performance_media_query' ||
          rule.id == 'business_logic_in_ui' ||
          rule.id == 'misplaced_layout_constraints' ||
          rule.id == 'unreleased_controllers' ||
          rule.id == 'hardcoded_ui_tokens' ||
          rule.id == 'setState_in_complex_builds' ||
          rule.id == 'missing_const_constructors') {
        continue;
      }
      rules.add(LegacyRuleAdapter(rule));
    }

    return rules;
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
}

/// A wrapper that adapts the legacy [Rule] or [CrossFileRule] to the new [AnalysisRule] interface.
final class LegacyRuleAdapter extends AnalysisRule {
  final Rule legacyRule;

  LegacyRuleAdapter(this.legacyRule) : super(config: legacyRule.config);

  @override
  String get id => legacyRule.id;

  @override
  String get name => legacyRule.name;

  @override
  String get description => legacyRule.description;

  @override
  bool get isCrossFile => legacyRule is CrossFileRule;

  @override
  List<Finding> analyzeFile(FileContext context) {
    if (legacyRule is CrossFileRule) return const [];
    final unit = context.nativeAst as CompilationUnit;
    return legacyRule.analyze(unit, context.filePath, context.sourceCode);
  }

  @override
  Future<List<Finding>> analyzeProject(
    Map<String, FileContext> contexts,
    ImportGraph graph,
  ) async {
    if (legacyRule is! CrossFileRule) return const [];
    final crossRule = legacyRule as CrossFileRule;

    final units = contexts.map((k, v) => MapEntry(k, v.nativeAst as CompilationUnit));
    final sources = contexts.map((k, v) => MapEntry(k, v.sourceCode));

    return crossRule.analyzeProject(units, sources);
  }
}
