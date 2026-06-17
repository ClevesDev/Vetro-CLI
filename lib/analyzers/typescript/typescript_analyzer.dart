import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
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
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/ts_node.dart';

/// TypeScript analyzer orchestrator for Vetro.
///
/// Coordinates parsing, rule execution, and result aggregation for
/// a TypeScript/JSX project (.ts, .tsx).
final class TypeScriptAnalyzer {
  TypeScriptAnalyzer();

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

  /// Analyzes a TypeScript project at [projectPath] using [config].
  Future<ProjectReport> analyze(
    String projectPath,
    VetroConfig config,
  ) async {
    final stopwatch = Stopwatch()..start();

    // Step 1: Discover files.
    final files = await _discoverFiles(projectPath, config);

    // Step 2: Locate Node & Parser.
    final nodeExec = await _findNodeExecutable();
    final parserScript = await _findParserScript();

    // Step 3: Parse files in parallel batches.
    final units = <String, TsNode>{};
    final sources = <String, String>{};
    final parseErrors = <String, List<Finding>>{};

    const batchSize = 8;
    for (var i = 0; i < files.length; i += batchSize) {
      final end = i + batchSize > files.length ? files.length : i + batchSize;
      final batch = files.sublist(i, end);

      await Future.wait(batch.map((file) async {
        final absolutePath = p.normalize(file.path);
        try {
          final source = await file.readAsString();
          sources[absolutePath] = source;

          final result = await Process.run(nodeExec, [parserScript, absolutePath]);
          if (result.exitCode != 0) {
            throw Exception(result.stderr.toString());
          }

          final jsonAst = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
          units[absolutePath] = TsNode.fromJson(jsonAst);
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
          if (!sources.containsKey(absolutePath)) {
            sources[absolutePath] = '';
          }
        }
      }));
    }

    // Step 4: Create rules from config.
    final rules = _createTsRules(config);
    final singleFileRules = rules.where((r) => r is! TsCrossFileRule).toList();
    final crossFileRules = rules.whereType<TsCrossFileRule>().toList();

    // Step 5: Run single-file rules.
    final fileFindings = <String, List<Finding>>{};
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

    // Step 6: Run cross-file rules.
    final crossFindings = <Finding>[];
    for (final rule in crossFileRules) {
      crossFindings.addAll(await rule.analyzeProject(units, sources));
    }

    // Merge cross-file findings.
    for (final finding in crossFindings) {
      fileFindings
          .putIfAbsent(finding.filePath, () => <Finding>[])
          .add(finding);
    }

    // Step 7: Build FileReports.
    final fileReports = <FileReport>[];
    for (final entry in sources.entries) {
      final filePath = entry.key;
      final source = entry.value;
      final findings = fileFindings[filePath] ?? const [];

      fileReports.add(
        FileReport(
          filePath: filePath,
          findings: findings,
          lineCount: _lineCount(source),
          analysisTimeMs: 0,
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

  /// Discovers TypeScript files (.ts, .tsx) matching the include/exclude globs in [config].
  Future<List<File>> _discoverFiles(
    String projectPath,
    VetroConfig config,
  ) async {
    final included = <String>{};

    // If the include globs only have .dart extensions, map them to .ts/.tsx extensions.
    final includePatterns = config.include.map((pattern) {
      if (pattern.endsWith('.dart')) {
        return pattern.replaceAll('.dart', '.ts*');
      }
      return pattern;
    }).toList();

    // Resolve include globs.
    for (final pattern in includePatterns) {
      final glob = Glob(pattern);
      await for (final entity in glob.list(root: projectPath)) {
        if (entity is File && (entity.path.endsWith('.ts') || entity.path.endsWith('.tsx'))) {
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

  int _lineCount(String source) {
    if (source.isEmpty) return 0;
    return source.split('\n').length;
  }
}
