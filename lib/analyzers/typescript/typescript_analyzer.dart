import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;
import 'package:vetro/analyzers/typescript/rules/ts_circular_dependency_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_cognitive_complexity_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_cyclomatic_complexity_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_intent_gap_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_low_cohesion_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_low_entropy_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_semantic_duplication_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_tight_coupling_rule.dart';
import 'package:vetro/core/adapters/typescript/typescript_adapter.dart';
import 'package:vetro/core/models/base_analyzer.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/ts_node.dart';
import 'package:vetro/core/rules/rule.dart';

import 'package:vetro/core/rules/cyclomatic_complexity_rule.dart' as core_rules;
import 'package:vetro/core/rules/low_entropy_rule.dart' as core_rules;
import 'package:vetro/core/rules/intent_gap_rule.dart' as core_rules;

/// TypeScript analyzer orchestrator for Vetro.
///
/// Coordinates parsing, rule execution, and result aggregation for
/// a TypeScript/JSX project (.ts, .tsx).
final class TypeScriptAnalyzer extends BaseAnalyzer<TsNode> {
  TypeScriptAnalyzer();

  Set<String> _allFiles = {};

  @override
  List<String> get supportedExtensions => const ['.ts', '.tsx', '.js', '.jsx'];

  @override
  Future<Map<String, TsNode>> parseFiles(List<File> files, VetroConfig config) async {
    _allFiles = files.map((f) => p.normalize(f.path)).toSet();

    final nodeExec = await _findNodeExecutable();
    final parserScript = await _findParserScript();
    final parsed = <String, TsNode>{};

    const batchSize = 8;
    for (var i = 0; i < files.length; i += batchSize) {
      final end = i + batchSize > files.length ? files.length : i + batchSize;
      final batch = files.sublist(i, end);

      await Future.wait(batch.map((file) async {
        final absolutePath = p.normalize(file.path);
        try {
          final result = await Process.run(nodeExec, [parserScript, absolutePath]);
          if (result.exitCode != 0) {
            throw Exception(result.stderr.toString());
          }

          final jsonAst = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
          parsed[absolutePath] = TsNode.fromJson(jsonAst);
        } catch (_) {
          // Handled as parse errors by BaseAnalyzer
        }
      }));
    }
    return parsed;
  }

  @override
  FileContext adaptToContext(TsNode ast, String filePath, String source) {
    final adapter = TsAdapter(allFiles: _allFiles);
    return adapter.adapt(ast, filePath, source);
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

    // Load remaining TS rules
    final tsRules = _createTsRules(config);
    for (final rule in tsRules) {
      if (rule.id == 'cyclomatic_complexity' || rule.id == 'low_entropy' || rule.id == 'intent_gap') {
        continue;
      }
      rules.add(TsLegacyRuleAdapter(rule));
    }

    return rules;
  }

  /// Creates and returns all active TypeScript rules based on [config].
  List<TsRule> _createTsRules(VetroConfig config) {
    final rules = <TsRule>[];

    final rulesMap = <String, TsRule Function(RuleConfig)>{
      'cyclomatic_complexity': (c) => TsCyclomaticComplexityRule(config: c),
      'cognitive_complexity': (c) => TsCognitiveComplexityRule(config: c),
      'low_entropy': (c) => TsLowEntropyRule(config: c),
      'intent_gap': (c) => TsIntentGapRule(config: c),
      'low_cohesion': (c) => TsLowCohesionRule(config: c),
      'tight_coupling': (c) => TsTightCouplingRule(config: c),
      'circular_dependency': (c) => TsCircularDependencyRule(config: c),
      'semantic_duplication': (c) => TsSemanticDuplicationRule(config: c),
    };

    for (final entry in rulesMap.entries) {
      final ruleConfig = config.ruleConfig(entry.key);
      if (ruleConfig.enabled) {
        rules.add(entry.value(ruleConfig));
      }
    }
    return rules;
  }

  /// Finds the Node.js executable on the system, with fallback.
  Future<String> _findNodeExecutable() async {
    try {
      final result = await Process.run('node', ['-v']);
      if (result.exitCode == 0) {
        return 'node';
      }
    } catch (_) {}

    // Fallback path specifically for development environments
    const cursorNodePath = '/usr/share/cursor/resources/app/resources/helpers/node';
    if (File(cursorNodePath).existsSync()) {
      return cursorNodePath;
    }

    throw StateError(
      'Node.js runtime not found. To analyze TypeScript projects, please install Node.js (v18+) '
      'and ensure the "node" executable is in your PATH.',
    );
  }

  /// Locates the ts_parser.js script path.
  Future<String> _findParserScript() async {
    final packageUri = Uri.parse('package:vetro/analyzers/typescript/parser/ts_parser.js');
    final resolved = await Isolate.resolvePackageUri(packageUri);
    if (resolved != null && resolved.isScheme('file')) {
      return resolved.toFilePath();
    }

    // Fallback: check relative to Platform.script
    try {
      final scriptPath = Platform.script.toFilePath();
      var dir = p.dirname(scriptPath);
      // If run via dart command, script might be in bin/vetro.dart
      while (dir != p.separator && dir.isNotEmpty) {
        final localPath = p.join(dir, 'lib', 'analyzers', 'typescript', 'parser', 'ts_parser.js');
        if (File(localPath).existsSync()) {
          return localPath;
        }
        final parent = p.dirname(dir);
        if (parent == dir) break;
        dir = parent;
      }
    } catch (_) {}

    // Default package structure fallback
    final projectDir = Directory.current.path;
    final fallbackPath = p.join(projectDir, 'lib', 'analyzers', 'typescript', 'parser', 'ts_parser.js');
    if (File(fallbackPath).existsSync()) {
      return fallbackPath;
    }

    throw StateError('Cannot locate ts_parser.js helper script. Ensure Vetro is installed correctly.');
  }
}

/// A wrapper that adapts the legacy [TsRule] or [TsCrossFileRule] to the new [AnalysisRule] interface.
final class TsLegacyRuleAdapter extends AnalysisRule {
  final TsRule legacyRule;

  TsLegacyRuleAdapter(this.legacyRule) : super(config: legacyRule.config);

  @override
  String get id => legacyRule.id;

  @override
  String get name => legacyRule.name;

  @override
  String get description => legacyRule.description;

  @override
  bool get isCrossFile => legacyRule is TsCrossFileRule;

  @override
  List<Finding> analyzeFile(FileContext context) {
    if (legacyRule is TsCrossFileRule) return const [];
    final root = context.nativeAst as TsNode;
    return legacyRule.analyze(root, context.filePath, context.sourceCode);
  }

  @override
  Future<List<Finding>> analyzeProject(
    Map<String, FileContext> contexts,
    ImportGraph graph,
  ) async {
    if (legacyRule is! TsCrossFileRule) return const [];
    final crossRule = legacyRule as TsCrossFileRule;

    final roots = contexts.map((k, v) => MapEntry(k, v.nativeAst as TsNode));
    final sources = contexts.map((k, v) => MapEntry(k, v.sourceCode));

    return crossRule.analyzeProject(roots, sources);
  }
}
