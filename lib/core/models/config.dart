/// Configuration model for Vetro analysis.
///
/// Parsed from `vetro.yaml` — defines which rules are active,
/// their thresholds, and which files to include/exclude.
library;

import 'package:vetro/core/models/finding.dart';
import 'package:yaml/yaml.dart';

/// Top-level configuration for a Vetro analysis run.
final class VetroConfig {
  const VetroConfig({
    this.include = const ['lib/*.dart', 'lib/**/*.dart'],
    this.exclude = const [
      '**/*.g.dart',
      '**/*.freezed.dart',
      '**/*.mocks.dart',
    ],
    this.rules = const {},
    this.outputFormat = OutputFormat.terminal,
    this.color = true,
    this.verbose = false,
    this.autoExcludeGenerated = true,
  });

  /// Parses configuration from YAML string.
  factory VetroConfig.fromYaml(String yamlContent) {
    var doc = loadYaml(yamlContent);
    if (doc is! YamlMap) {
      return VetroConfig.defaults();
    }

    // Unpack top-level 'vetro' key if present to support standard vetro.yaml nesting.
    if (doc.containsKey('vetro') && doc['vetro'] is YamlMap) {
      doc = doc['vetro'] as YamlMap;
    }

    final include = doc['include'] is YamlList
        ? (doc['include'] as YamlList).map((e) => e.toString()).toList()
        : const ['lib/*.dart', 'lib/**/*.dart'];

    final exclude = doc['exclude'] is YamlList
        ? (doc['exclude'] as YamlList).map((e) => e.toString()).toList()
        : const ['**/*.g.dart', '**/*.freezed.dart', '**/*.mocks.dart'];

    final rules = Map<String, RuleConfig>.from(VetroConfig.defaults().rules);
    final docRules = doc['rules'];
    if (docRules is YamlMap) {
      for (final entry in docRules.entries) {
        final ruleId = entry.key.toString();
        final ruleVal = entry.value;

        if (ruleVal is YamlMap) {
          final enabled = ruleVal['enabled'] is bool
              ? ruleVal['enabled'] as bool
              : true;
          final severityStr = ruleVal['severity']?.toString();
          final severity = Severity.values.firstWhere(
            (s) => s.name == severityStr,
            orElse: () => Severity.warning,
          );

          final thresholds = <String, double>{};
          final docThresholds = ruleVal['thresholds'];
          if (docThresholds is YamlMap) {
            for (final thEntry in docThresholds.entries) {
              final thVal = thEntry.value;
              if (thVal is num) {
                thresholds[thEntry.key.toString()] = thVal.toDouble();
              }
            }
          }

          final options = <String, dynamic>{};
          for (final optEntry in ruleVal.entries) {
            final key = optEntry.key.toString();
            if (key != 'enabled' && key != 'severity' && key != 'thresholds') {
              final val = optEntry.value;
              if (val is YamlList) {
                options[key] = val.map((e) => e.toString()).toList();
              } else if (val is YamlMap) {
                options[key] = Map<String, dynamic>.from(val);
              } else {
                options[key] = val;
              }
            }
          }

          rules[ruleId] = RuleConfig(
            enabled: enabled,
            severity: severity,
            thresholds: thresholds,
            options: options,
          );
        }
      }
    }

    final outputFormatStr = doc['format']?.toString();
    final outputFormat = outputFormatStr != null
        ? OutputFormat.fromString(outputFormatStr)
        : OutputFormat.terminal;

    final color = doc['color'] is bool ? doc['color'] as bool : true;
    final verbose = doc['verbose'] is bool ? doc['verbose'] as bool : false;
    final autoExcludeGenerated = doc['auto_exclude_generated'] is bool
        ? doc['auto_exclude_generated'] as bool
        : true;

    return VetroConfig(
      include: include,
      exclude: exclude,
      rules: rules,
      outputFormat: outputFormat,
      color: color,
      verbose: verbose,
      autoExcludeGenerated: autoExcludeGenerated,
    );
  }

  /// Default configuration with all rules enabled at default thresholds.
  factory VetroConfig.defaults() => const VetroConfig(
        rules: {
          'semantic_duplication': RuleConfig(
            enabled: true,
            severity: Severity.warning,
            thresholds: {'similarity': 0.80},
          ),
          'orphaned_abstraction': RuleConfig(
            enabled: true,
            severity: Severity.info,
          ),
          'copy_mutate': RuleConfig(
            enabled: true,
            severity: Severity.warning,
            thresholds: {
              'similarity': 0.70,
              'max_diff_ratio': 0.15,
            },
          ),
          'intent_gap': RuleConfig(
            enabled: true,
            severity: Severity.info,
            thresholds: {'min_complexity': 5.0},
          ),
          'cyclomatic_complexity': RuleConfig(
            enabled: true,
            severity: Severity.warning,
            thresholds: {'max_complexity': 15.0},
          ),
          'fragile_test': RuleConfig(
            enabled: true,
            severity: Severity.info,
            thresholds: {'max_mocks': 3.0},
          ),
          'circular_dependency': RuleConfig(
            enabled: true,
            severity: Severity.warning,
          ),
          'tight_coupling': RuleConfig(
            enabled: true,
            severity: Severity.warning,
            thresholds: {'max_coupling': 0.25},
          ),
          'halstead_complexity': RuleConfig(
            enabled: true,
            severity: Severity.warning,
            thresholds: {'max_effort': 50000.0},
          ),
          'low_entropy': RuleConfig(
            enabled: true,
            severity: Severity.warning,
            thresholds: {'min_entropy': 1.8, 'min_nodes': 30.0, 'min_identifier_entropy': 2.0},
          ),
          'eigenvector_centrality': RuleConfig(
            enabled: true,
            severity: Severity.warning,
            thresholds: {'max_centrality': 0.40},
          ),
          'low_cohesion': RuleConfig(
            enabled: true,
            severity: Severity.warning,
            thresholds: {'min_cohesion': 0.15, 'min_methods': 3.0},
          ),
          'boundary_violation': const RuleConfig(
            enabled: true,
            severity: Severity.error,
            options: {
              'layers': [
                'domain',
                'application',
                'infrastructure',
                'presentation'
              ]
            },
          ),
          'cognitive_complexity': const RuleConfig(
            enabled: true,
            severity: Severity.warning,
            thresholds: {'max_cognitive_complexity': 15.0},
          ),
          'local_clustering_coefficient': const RuleConfig(
            enabled: true,
            severity: Severity.warning,
            thresholds: {'min_clustering': 0.15, 'min_connections': 4.0},
          ),
          'performance_media_query': const RuleConfig(
            enabled: true,
            severity: Severity.warning,
          ),
          'business_logic_in_ui': const RuleConfig(
            enabled: true,
            severity: Severity.error,
          ),
          'misplaced_layout_constraints': const RuleConfig(
            enabled: true,
            severity: Severity.error,
          ),
          'unreleased_controllers': const RuleConfig(
            enabled: true,
            severity: Severity.error,
          ),
          'hardcoded_ui_tokens': const RuleConfig(
            enabled: true,
            severity: Severity.warning,
          ),
          'setState_in_complex_builds': const RuleConfig(
            enabled: true,
            severity: Severity.warning,
            thresholds: {'max_build_complexity': 12.0},
          ),
          'missing_const_constructors': const RuleConfig(
            enabled: true,
            severity: Severity.warning,
          ),
        },
      );

  /// Glob patterns for files to include.
  final List<String> include;

  /// Glob patterns for files to exclude.
  final List<String> exclude;

  /// Per-rule configuration, keyed by rule ID.
  final Map<String, RuleConfig> rules;

  /// Output format for the report.
  final OutputFormat outputFormat;

  /// Whether to use ANSI colors in terminal output.
  final bool color;

  /// Whether to show verbose/detailed output.
  final bool verbose;

  /// Whether to auto-exclude generated files.
  final bool autoExcludeGenerated;

  /// Returns the configuration for a specific rule, or a disabled
  /// config if the rule is not listed.
  RuleConfig ruleConfig(String ruleId) =>
      rules[ruleId] ?? const RuleConfig(enabled: false);
}

/// Configuration for a single analysis rule.
final class RuleConfig {
  const RuleConfig({
    this.enabled = true,
    this.severity = Severity.warning,
    this.thresholds = const {},
    this.options = const {},
  });

  /// Whether this rule is active.
  final bool enabled;

  /// The severity to assign to findings from this rule.
  final Severity severity;

  /// Rule-specific thresholds, keyed by parameter name.
  /// Example: `{'similarity': 0.80, 'max_complexity': 15.0}`
  final Map<String, double> thresholds;

  /// Rule-specific options, keyed by option name.
  final Map<String, dynamic> options;

  /// Convenience getter for a specific threshold with a default.
  double threshold(String key, {double defaultValue = 0.0}) =>
      thresholds[key] ?? defaultValue;
}

/// Output format options.
enum OutputFormat {
  terminal,
  json,
  markdown,
  prompt;

  /// Parses a string to an OutputFormat, defaulting to [terminal].
  static OutputFormat fromString(String value) => switch (value) {
        'json' => OutputFormat.json,
        'markdown' || 'md' => OutputFormat.markdown,
        'prompt' => OutputFormat.prompt,
        _ => OutputFormat.terminal,
      };
}
