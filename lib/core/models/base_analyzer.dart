import 'dart:io';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/rules/rule.dart';

/// Base class that coordinates the analysis pipeline.
///
/// Subclasses (DartAnalyzer, TypeScriptAnalyzer) implement:
/// 1. File parsing (via `parseFiles`)
/// 2. AST to Context mapping (via `adaptToContext`)
/// 3. Import graph extraction (via `extractImportGraph`)
/// 4. Rule loading (via `loadRules`)
abstract class BaseAnalyzer<AST> {
  const BaseAnalyzer();

  /// The file extension list that this analyzer supports.
  List<String> get supportedExtensions;

  /// Hook implemented by subclasses to parse a list of files.
  /// Subclasses can parse in parallel, sequentially, or in batches.
  Future<Map<String, AST>> parseFiles(List<File> files, VetroConfig config);

  /// Hook implemented by subclasses to map a parsed AST to a unified [FileContext].
  FileContext adaptToContext(AST ast, String filePath, String source);

  /// Hook implemented by subclasses to load rules for this analyzer.
  List<AnalysisRule> loadRules(VetroConfig config);

  /// Executes the unified analysis pipeline.
  Future<ProjectReport> analyze(String projectPath, VetroConfig config) async {
    final stopwatch = Stopwatch()..start();

    // Step 1: Discover files.
    final files = await discoverFiles(projectPath, config);

    // Step 2: Parse files (using the subclass hook).
    final asts = <String, AST>{};
    final sources = <String, String>{};
    final parseErrors = <String, List<Finding>>{};

    final parsedMap = await parseFiles(files, config);

    for (final file in files) {
      final absolutePath = p.normalize(file.path);
      try {
        final source = await file.readAsString();
        if (config.autoExcludeGenerated && isGeneratedCode(source)) {
          if (config.verbose) {
            print('Skipping auto-generated file: ${p.relative(absolutePath, from: projectPath)}');
          }
          continue;
        }

        sources[absolutePath] = source;

        final ast = parsedMap[absolutePath];
        if (ast == null) {
          throw StateError('File not parsed by parser');
        }
        asts[absolutePath] = ast;
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
    }

    // Step 3: Build Contexts.
    final contexts = <String, FileContext>{};
    for (final entry in asts.entries) {
      final filePath = entry.key;
      contexts[filePath] = adaptToContext(entry.value, filePath, sources[filePath]!);
    }

    // Step 4: Load and Partition Rules.
    final rules = loadRules(config);
    final singleFileRules = rules.where((r) => !r.isCrossFile).toList();
    final crossFileRules = rules.where((r) => r.isCrossFile).toList();

    final fileFindings = <String, List<Finding>>{};
    fileFindings.addAll(parseErrors);

    // Step 5: Run single-file rules.
    for (final entry in contexts.entries) {
      final filePath = entry.key;
      final context = entry.value;
      final findings = <Finding>[];

      for (final rule in singleFileRules) {
        findings.addAll(rule.analyzeFile(context));
      }

      fileFindings.putIfAbsent(filePath, () => <Finding>[]).addAll(findings);
    }

    // Step 6: Run cross-file rules.
    final importGraph = <String, List<String>>{};
    for (final entry in contexts.entries) {
      importGraph[entry.key] = entry.value.imports
          .map((e) => e.resolvedPath)
          .whereType<String>()
          .toList();
    }
    final crossFindings = <Finding>[];
    for (final rule in crossFileRules) {
      crossFindings.addAll(await rule.analyzeProject(contexts, importGraph));
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
          lineCount: lineCount(source),
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

  /// Discovers source files matching the include/exclude globs in [config].
  Future<List<File>> discoverFiles(
    String projectPath,
    VetroConfig config,
  ) async {
    final included = <String>{};

    final includePatterns = config.include.map((pattern) {
      if (pattern.endsWith('.dart') && !supportedExtensions.contains('.dart')) {
        final prefix = pattern.substring(0, pattern.length - 5);
        if (supportedExtensions.length == 1) {
          final ext = supportedExtensions.first;
          final extClean = ext.startsWith('.') ? ext.substring(1) : ext;
          return '$prefix$extClean';
        } else {
          final extensionsJoined = supportedExtensions.map((e) => e.startsWith('.') ? e.substring(1) : e).join(',');
          return '$prefix{$extensionsJoined}';
        }
      }
      return pattern;
    }).toList();

    for (final pattern in includePatterns) {
      final glob = Glob(pattern);
      await for (final entity in glob.list(root: projectPath)) {
        if (entity is File) {
          final isSupported = supportedExtensions.any((ext) => entity.path.endsWith(ext));
          if (isSupported) {
            included.add(p.normalize(entity.path));
          }
        }
      }
    }

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

    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// Checks if the given source content is marked as autogenerated.
  bool isGeneratedCode(String content) {
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

  int lineCount(String source) {
    if (source.isEmpty) return 0;
    return source.split('\n').length;
  }
}
