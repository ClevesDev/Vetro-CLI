import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:path/path.dart' as p;
import 'package:vetro/analyzers/python/rules/py_circular_dependency_rule.dart';
import 'package:vetro/analyzers/python/rules/py_cognitive_complexity_rule.dart';
import 'package:vetro/analyzers/python/rules/py_low_cohesion_rule.dart';
import 'package:vetro/analyzers/python/rules/py_rule.dart';
import 'package:vetro/analyzers/python/rules/py_semantic_duplication_rule.dart';
import 'package:vetro/analyzers/python/rules/py_tight_coupling_rule.dart';
import 'package:vetro/analyzers/python/adapters/python_adapter.dart';
import 'package:vetro/core/models/base_analyzer.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/py_node.dart';
import 'package:vetro/core/rules/rule.dart';

import 'package:vetro/core/rules/cyclomatic_complexity_rule.dart' as core_rules;
import 'package:vetro/core/rules/low_entropy_rule.dart' as core_rules;
import 'package:vetro/core/rules/intent_gap_rule.dart' as core_rules;
import 'package:vetro/core/rules/halstead_complexity_rule.dart' as core_rules;

/// Python analyzer orchestrator for Vetro.
///
/// Coordinates parsing, rule execution, and result aggregation for
/// a Python project (.py).
final class PythonAnalyzer extends BaseAnalyzer<PyNode> {
  PythonAnalyzer();

  Set<String> _allFiles = {};

  @override
  List<String> get supportedExtensions => const ['.py'];

  @override
  Future<Map<String, PyNode>> parseFiles(List<File> files, VetroConfig config) async {
    _allFiles = files.map((f) => p.normalize(f.path)).toSet();

    if (files.isEmpty) return const {};

    final pythonExec = await _findPythonExecutable();
    final parserScript = await _findParserScript();

    // If the number of files is small, parse sequentially to avoid isolate overhead
    if (files.length < 4) {
      final parsed = <String, PyNode>{};
      for (final file in files) {
        final absolutePath = p.normalize(file.path);
        try {
          final result = await Process.run(pythonExec, [parserScript, absolutePath]);
          if (result.exitCode != 0) {
            throw Exception(result.stderr.toString());
          }
          final jsonAst = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
          final astRoot = jsonAst['ast'] as Map<String, dynamic>;
          astRoot['comments'] = jsonAst['comments'];
          parsed[absolutePath] = PyNode.fromJson(astRoot);
        } catch (_) {}
      }
      return parsed;
    }

    // Otherwise, split files among workers and parse in parallel
    final numWorkers = math.min(Platform.numberOfProcessors, files.length);
    final chunks = List.generate(numWorkers, (_) => <String>[]);
    for (var i = 0; i < files.length; i++) {
      chunks[i % numWorkers].add(p.normalize(files[i].path));
    }

    final futures = <Future<Map<String, Map<String, dynamic>>>>[];
    for (var k = 0; k < numWorkers; k++) {
      final chunk = chunks[k];
      futures.add(
        Isolate.run(() => _parseFileChunk(
          filePaths: chunk,
          pythonExec: pythonExec,
          parserScript: parserScript,
        )),
      );
    }

    final results = await Future.wait(futures);
    final parsed = <String, PyNode>{};
    for (final res in results) {
      for (final entry in res.entries) {
        parsed[entry.key] = PyNode.fromJson(entry.value);
      }
    }
    return parsed;
  }

  static Future<Map<String, Map<String, dynamic>>> _parseFileChunk({
    required List<String> filePaths,
    required String pythonExec,
    required String parserScript,
  }) async {
    final result = <String, Map<String, dynamic>>{};
    for (final filePath in filePaths) {
      try {
        final procResult = await Process.run(pythonExec, [parserScript, filePath]);
        if (procResult.exitCode == 0) {
          final jsonAst = jsonDecode(procResult.stdout.toString()) as Map<String, dynamic>;
          final astRoot = jsonAst['ast'] as Map<String, dynamic>;
          astRoot['comments'] = jsonAst['comments'];
          result[filePath] = astRoot;
        }
      } catch (_) {}
    }
    return result;
  }

  @override
  FileContext adaptToContext(PyNode ast, String filePath, String source) {
    final adapter = PythonAdapter(allFiles: _allFiles);
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
    final halsteadConfig = config.ruleConfig('halstead_complexity');
    if (halsteadConfig.enabled) {
      rules.add(core_rules.HalsteadComplexityRule(config: halsteadConfig));
    }

    // Load remaining Python rules
    final pyRules = _createPyRules(config);
    for (final rule in pyRules) {
      if (rule.id == 'cyclomatic_complexity' ||
          rule.id == 'low_entropy' ||
          rule.id == 'intent_gap' ||
          rule.id == 'halstead_complexity') {
        continue;
      }
      rules.add(PyLegacyRuleAdapter(rule));
    }

    return rules;
  }

  /// Creates and returns all active Python rules based on [config].
  List<PyRule> _createPyRules(VetroConfig config) {
    final rules = <PyRule>[];

    final rulesMap = <String, PyRule Function(RuleConfig)>{
      'cognitive_complexity': (c) => PyCognitiveComplexityRule(config: c),
      'low_cohesion': (c) => PyLowCohesionRule(config: c),
      'tight_coupling': (c) => PyTightCouplingRule(config: c),
      'circular_dependency': (c) => PyCircularDependencyRule(config: c),
      'semantic_duplication': (c) => PySemanticDuplicationRule(config: c),
    };

    for (final entry in rulesMap.entries) {
      final ruleConfig = config.ruleConfig(entry.key);
      if (ruleConfig.enabled) {
        rules.add(entry.value(ruleConfig));
      }
    }
    return rules;
  }

  /// Finds a Python 3 executable on the system, with fallback.
  Future<String> _findPythonExecutable() async {
    for (final cmd in ['python3', 'python']) {
      try {
        final result = await Process.run(cmd, ['--version']);
        if (result.exitCode == 0) {
          return cmd;
        }
      } catch (_) {}
    }

    throw StateError(
      'Python 3 runtime not found. To analyze Python projects, please install Python 3 '
      'and ensure the "python3" or "python" executable is in your PATH.',
    );
  }

  /// Locates the py_parser.py script path.
  Future<String> _findParserScript() async {
    final packageUri = Uri.parse('package:vetro/analyzers/python/parser/py_parser.py');
    final resolved = await Isolate.resolvePackageUri(packageUri);
    if (resolved != null && resolved.isScheme('file')) {
      return resolved.toFilePath();
    }

    // Fallback: check relative to Platform.script
    try {
      final scriptPath = Platform.script.toFilePath();
      var dir = p.dirname(scriptPath);
      while (dir != p.separator && dir.isNotEmpty) {
        final localPath = p.join(dir, 'lib', 'analyzers', 'python', 'parser', 'py_parser.py');
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
    final fallbackPath = p.join(projectDir, 'lib', 'analyzers', 'python', 'parser', 'py_parser.py');
    if (File(fallbackPath).existsSync()) {
      return fallbackPath;
    }

    throw StateError('Cannot locate py_parser.py helper script. Ensure Vetro is installed correctly.');
  }
}

/// A wrapper that adapts the legacy [PyRule] or [PyCrossFileRule] to the new [AnalysisRule] interface.
final class PyLegacyRuleAdapter extends AnalysisRule {
  final PyRule legacyRule;

  PyLegacyRuleAdapter(this.legacyRule) : super(config: legacyRule.config);

  @override
  String get id => legacyRule.id;

  @override
  String get name => legacyRule.name;

  @override
  String get description => legacyRule.description;

  @override
  bool get isCrossFile => legacyRule is PyCrossFileRule;

  @override
  List<Finding> analyzeFile(FileContext context) {
    if (legacyRule is PyCrossFileRule) return const [];
    final root = context.nativeAst as PyNode;
    return legacyRule.analyze(root, context.filePath, context.sourceCode);
  }

  @override
  Future<List<Finding>> analyzeProject(
    Map<String, FileContext> contexts,
    ImportGraph graph,
  ) async {
    if (legacyRule is! PyCrossFileRule) return const [];
    final crossRule = legacyRule as PyCrossFileRule;

    final roots = contexts.map((k, v) => MapEntry(k, v.nativeAst as PyNode));
    final sources = contexts.map((k, v) => MapEntry(k, v.sourceCode));

    return crossRule.analyzeProject(roots, sources);
  }
}
