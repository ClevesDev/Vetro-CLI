// ignore_for_file: avoid_print
/// Vetro CLI entry point.
///
/// Parses command line arguments, loads configuration, executes analysis,
/// formats output using the appropriate reporter, and handles exit codes.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:vetro/core/report/ansi.dart';
import 'package:vetro/vetro.dart';
import 'package:vetro/cli/git_diff_parser.dart';

Future<void> main(List<String> arguments) async {
  final initParser = ArgParser()
    ..addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing vetro.yaml if it exists.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show help for init command.',
    );

  final parser = ArgParser();

  final diffParser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show help for diff command.',
    )
    ..addOption(
      'format',
      abbr: 'f',
      allowed: ['terminal', 'json', 'markdown', 'prompt'],
      defaultsTo: 'terminal',
      help: 'Select the output format.',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Write report output to the specified file path.',
    )
    ..addMultiOption(
      'exclude',
      abbr: 'e',
      help: 'Additional glob patterns to exclude from analysis.',
    )
    ..addFlag(
      'color',
      defaultsTo: true,
      help: 'Use ANSI escape codes for colored terminal output.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show detailed/verbose execution logging.',
    )
    ..addOption(
      'fail-on-severity',
      allowed: ['error', 'warning', 'info', 'none'],
      defaultsTo: 'none',
      help: 'Exit with non-zero code if findings equal or exceed this severity.',
    )
    ..addOption(
      'language',
      abbr: 'l',
      allowed: ['dart', 'typescript', 'python', 'auto'],
      defaultsTo: 'auto',
      help: 'Force a specific programming language analyzer or let it auto-detect.',
    );

  parser
    ..addCommand('init', initParser)
    ..addCommand('diff', diffParser)
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message and usage info.',
    )
    ..addOption(
      'format',
      abbr: 'f',
      allowed: ['terminal', 'json', 'markdown', 'prompt'],
      defaultsTo: 'terminal',
      help: 'Select the output format.',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Write report output to the specified file path.',
    )
    ..addMultiOption(
      'exclude',
      abbr: 'e',
      help: 'Additional glob patterns to exclude from analysis.',
    )
    ..addFlag(
      'color',
      defaultsTo: true,
      help: 'Use ANSI escape codes for colored terminal output.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show detailed/verbose execution logging.',
    )
    ..addOption(
      'fail-on-severity',
      allowed: ['error', 'warning', 'info', 'none'],
      defaultsTo: 'none',
      help: 'Exit with non-zero code if findings equal or exceed this severity.',
    )
    ..addOption(
      'language',
      abbr: 'l',
      allowed: ['dart', 'typescript', 'python', 'auto'],
      defaultsTo: 'auto',
      help: 'Force a specific programming language analyzer or let it auto-detect.',
    );

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } on ArgParserException catch (e) {
    stderr.writeln(Ansi.red('Error: ${e.message}'));
    stderr.writeln();
    stderr.writeln(parser.usage);
    exit(1);
  }

  if (argResults.command?.name == 'init') {
    final initResults = argResults.command!;
    if (initResults['help'] as bool) {
      print('Vetro — Initialize Configuration');
      print('Usage: vetro init [options] [project_path]');
      print('');
      print(initParser.usage);
      exit(0);
    }
    
    var targetPath = Directory.current.path;
    if (initResults.rest.isNotEmpty) {
      targetPath = initResults.rest.first;
    }
    await _handleInit(targetPath, force: initResults['force'] as bool);
    exit(0);
  }

  if (argResults.command?.name == 'diff') {
    final diffResults = argResults.command!;
    if (diffResults['help'] as bool) {
      print('Vetro — Git Diff Analysis');
      print('Usage: vetro diff [options] [base_ref]');
      print('');
      print(diffParser.usage);
      exit(0);
    }

    final baseRef = diffResults.rest.isNotEmpty ? diffResults.rest.first : null;
    await _handleDiff(baseRef, diffResults);
    exit(0);
  }

  if (argResults['help'] as bool) {
    print('Vetro — AI Code Debt Scanner');
    print('Usage: vetro [options] <project_path>');
    print('       vetro init [options] [project_path]');
    print('       vetro diff [options] [base_ref]');
    print('');
    print(parser.usage);
    print('Commands:');
    print('  init       Initialize a new vetro.yaml configuration file.');
    print('  diff       Analyze debt only on modified lines in Git diff.');
    exit(0);
  }

  // Determine target project path.
  var targetPath = Directory.current.path;
  if (argResults.rest.isNotEmpty) {
    targetPath = argResults.rest.first;
  }

  final targetDir = Directory(targetPath);
  if (!targetDir.existsSync()) {
    stderr.writeln(Ansi.red('Error: Directory does not exist at "$targetPath"'));
    exit(1);
  }

  final absoluteTargetPath = p.normalize(targetDir.absolute.path);

  // Configure ANSI colors.
  final useColor = argResults['color'] as bool;
  Ansi.enabled = useColor;

  // Load vetro.yaml if it exists.
  final yamlFile = File(p.join(absoluteTargetPath, 'vetro.yaml'));
  var config = VetroConfig.defaults();

  if (yamlFile.existsSync()) {
    try {
      final content = yamlFile.readAsStringSync();
      config = VetroConfig.fromYaml(content);
    } catch (e) {
      if (useColor) {
        stderr.writeln(Ansi.yellow('Warning: Failed to parse vetro.yaml, using defaults. Error: $e'));
      } else {
        stderr.writeln('Warning: Failed to parse vetro.yaml, using defaults. Error: $e');
      }
    }
  }

  // CLI overrides.
  final formatOption = argResults['format'] as String;
  final outputFormat = OutputFormat.fromString(formatOption);

  final extraExcludes = argResults['exclude'] as List<String>;
  final excludeList = [...config.exclude, ...extraExcludes];

  final verboseOption = argResults['verbose'] as bool;
  final languageOption = argResults['language'] as String;
  var language = AnalysisLanguage.fromString(languageOption);

  if (language == AnalysisLanguage.auto) {
    language = await _detectLanguage(absoluteTargetPath);
  }

  config = VetroConfig(
    include: config.include,
    exclude: excludeList,
    rules: config.rules,
    outputFormat: outputFormat,
    color: useColor,
    verbose: config.verbose || verboseOption,
  );

  if (config.verbose) {
    print(Ansi.dim('Language selected: ${language.name.toUpperCase()}'));
    print(Ansi.dim('Loading analyzer rules registry...'));
  }

  if (config.verbose) {
    print(Ansi.dim('Starting analysis of "$absoluteTargetPath"...'));
  } else if (config.outputFormat == OutputFormat.terminal) {
    print('Analyzing codebase (${language.name})...');
  }

  ProjectReport report;
  try {
    if (language == AnalysisLanguage.typescript) {
      final analyzer = TypeScriptAnalyzer();
      report = await analyzer.analyze(absoluteTargetPath, config);
    } else if (language == AnalysisLanguage.python) {
      final analyzer = PythonAnalyzer();
      report = await analyzer.analyze(absoluteTargetPath, config);
    } else {
      final analyzer = DartAnalyzer();
      report = await analyzer.analyze(absoluteTargetPath, config);
    }
  } catch (e, stack) {
    stderr.writeln(Ansi.red('Fatal error during analysis: $e'));
    if (config.verbose) {
      stderr.writeln(stack);
    }
    exit(1);
  }

  // Format using selected reporter.
  final reporter = switch (config.outputFormat) {
    OutputFormat.terminal => const TerminalReporter(),
    OutputFormat.json => const JsonReporter(),
    OutputFormat.markdown => const MarkdownReporter(),
    OutputFormat.prompt => const PromptReporter(),
  };

  final formattedOutput = reporter.format(report);

  // Write or print results.
  final outputPath = argResults['output'] as String?;
  if (outputPath != null) {
    try {
      final outputFile = File(outputPath);
      outputFile.writeAsStringSync(formattedOutput);
      if (config.verbose || config.outputFormat == OutputFormat.terminal) {
        print(Ansi.green('Report written to: $outputPath'));
      }
    } catch (e) {
      stderr.writeln(Ansi.red('Error: Failed to write output to "$outputPath". Error: $e'));
      exit(1);
    }
  } else {
    print(formattedOutput);
  }

  // Handle fail-on-severity exit code.
  final failSeverityStr = argResults['fail-on-severity'] as String;
  if (failSeverityStr != 'none') {
    final failSeverity = Severity.values.firstWhere(
      (s) => s.name == failSeverityStr,
    );

    final triggerFindings = report.allFindings.where(
      (f) => f.severity.isAtLeast(failSeverity),
    );

    if (triggerFindings.isNotEmpty) {
      if (config.outputFormat == OutputFormat.terminal) {
        stderr.writeln(Ansi.red(
          'Build failed: Found ${triggerFindings.length} issues at or above severity "$failSeverityStr".',
        ));
      }
      exit(1);
    }
  }

  exit(0);
}

enum AnalysisLanguage {
  dart,
  typescript,
  python,
  auto;

  static AnalysisLanguage fromString(String value) {
    return switch (value.toLowerCase()) {
      'dart' => AnalysisLanguage.dart,
      'typescript' || 'ts' => AnalysisLanguage.typescript,
      'python' || 'py' => AnalysisLanguage.python,
      _ => AnalysisLanguage.auto,
    };
  }
}

Future<AnalysisLanguage> _detectLanguage(String projectPath) async {
  // Check python configurations first
  if (File(p.join(projectPath, 'requirements.txt')).existsSync() ||
      File(p.join(projectPath, 'pyproject.toml')).existsSync() ||
      File(p.join(projectPath, 'setup.py')).existsSync()) {
    return AnalysisLanguage.python;
  }

  // Check tsconfig.json or package.json
  if (File(p.join(projectPath, 'tsconfig.json')).existsSync() ||
      File(p.join(projectPath, 'package.json')).existsSync()) {
    return AnalysisLanguage.typescript;
  }

  // Count .dart vs .ts/.tsx files vs .py files
  var dartCount = 0;
  var tsCount = 0;
  var pyCount = 0;

  try {
    final dir = Directory(projectPath);
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final path = entity.path;
        if (path.endsWith('.dart')) {
          dartCount++;
        } else if (path.endsWith('.ts') || path.endsWith('.tsx')) {
          tsCount++;
        } else if (path.endsWith('.py')) {
          pyCount++;
        }
      }
    }
  } catch (_) {}

  if (pyCount > dartCount && pyCount > tsCount) {
    return AnalysisLanguage.python;
  }
  if (tsCount > dartCount) {
    return AnalysisLanguage.typescript;
  }
  return AnalysisLanguage.dart;
}

Future<void> _handleInit(String targetPath, {required bool force}) async {
  final targetDir = Directory(targetPath);
  if (!targetDir.existsSync()) {
    stderr.writeln(Ansi.red('Error: Directory does not exist at "$targetPath"'));
    exit(1);
  }

  final absoluteTargetPath = p.normalize(targetDir.absolute.path);
  final yamlFile = File(p.join(absoluteTargetPath, 'vetro.yaml'));

  if (yamlFile.existsSync() && !force) {
    stderr.writeln(Ansi.red('Error: vetro.yaml already exists at "$absoluteTargetPath".'));
    stderr.writeln('Use --force (or -f) to overwrite.');
    exit(1);
  }

  print('Initializing Vetro configuration...');
  final language = await _detectLanguage(absoluteTargetPath);
  print('Detected dominant language: ${language.name.toUpperCase()}');

  final yamlContent = switch (language) {
    AnalysisLanguage.dart => '''
vetro:
  version: 1

  # Files to include in the analysis
  include:
    - lib/**/*.dart

  # Files to exclude from the analysis
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/*.mocks.dart"
''',
    AnalysisLanguage.typescript => '''
vetro:
  version: 1

  # Files to include in the analysis
  include:
    - src/**/*.ts
    - src/**/*.tsx
    - lib/**/*.ts
    - lib/**/*.tsx

  # Files to exclude from the analysis
  exclude:
    - "**/node_modules/**"
    - "**/*.d.ts"
''',
    AnalysisLanguage.python => '''
vetro:
  version: 1

  # Files to include in the analysis
  include:
    - "**/*.py"

  # Files to exclude from the analysis
  exclude:
    - "**/venv/**"
    - "**/.venv/**"
    - "**/__pycache__/**"
''',
    _ => '''
vetro:
  version: 1

  # Files to include in the analysis
  include:
    - lib/**/*.dart

  # Files to exclude from the analysis
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/*.mocks.dart"
''',
  };

  try {
    yamlFile.writeAsStringSync(yamlContent);
    print(Ansi.green('Created vetro.yaml successfully at ${yamlFile.path}'));
  } catch (e) {
    stderr.writeln(Ansi.red('Error: Failed to write vetro.yaml. Error: $e'));
    exit(1);
  }
}

Future<void> _handleDiff(String? baseRef, ArgResults argResults) async {
  final targetPath = Directory.current.path;
  final targetDir = Directory(targetPath);
  final absoluteTargetPath = p.normalize(targetDir.absolute.path);

  final useColor = argResults['color'] as bool;
  Ansi.enabled = useColor;

  final isGitRepo = Directory(p.join(absoluteTargetPath, '.git')).existsSync() ||
      await Process.run('git', ['rev-parse', '--is-inside-work-tree'], workingDirectory: absoluteTargetPath)
          .then((res) => res.exitCode == 0)
          .catchError((_) => false);

  if (!isGitRepo) {
    stderr.writeln(Ansi.red('Error: Target path is not a git repository, or git is not installed.'));
    exit(1);
  }

  final diffParser = GitDiffParser();
  final modifiedLinesByFile = await diffParser.getModifiedLines(absoluteTargetPath, baseRef);

  if (argResults['verbose'] as bool) {
    print(Ansi.dim('Modified files in diff: ${modifiedLinesByFile.keys.length}'));
    for (final entry in modifiedLinesByFile.entries) {
      print(Ansi.dim('  ${entry.key}: lines ${entry.value}'));
    }
  }

  final yamlFile = File(p.join(absoluteTargetPath, 'vetro.yaml'));
  var config = VetroConfig.defaults();

  if (yamlFile.existsSync()) {
    try {
      final content = yamlFile.readAsStringSync();
      config = VetroConfig.fromYaml(content);
    } catch (e) {
      stderr.writeln(Ansi.yellow('Warning: Failed to parse vetro.yaml, using defaults.'));
    }
  }

  final formatOption = argResults['format'] as String;
  final outputFormat = OutputFormat.fromString(formatOption);

  final extraExcludes = argResults['exclude'] as List<String>;
  final excludeList = [...config.exclude, ...extraExcludes];

  final verboseOption = argResults['verbose'] as bool;
  final languageOption = argResults['language'] as String;
  var language = AnalysisLanguage.fromString(languageOption);

  if (language == AnalysisLanguage.auto) {
    language = await _detectLanguage(absoluteTargetPath);
  }

  config = VetroConfig(
    include: config.include,
    exclude: excludeList,
    rules: config.rules,
    outputFormat: outputFormat,
    color: useColor,
    verbose: config.verbose || verboseOption,
  );

  ProjectReport report;
  try {
    if (language == AnalysisLanguage.typescript) {
      final analyzer = TypeScriptAnalyzer();
      report = await analyzer.analyze(absoluteTargetPath, config);
    } else if (language == AnalysisLanguage.python) {
      final analyzer = PythonAnalyzer();
      report = await analyzer.analyze(absoluteTargetPath, config);
    } else {
      final analyzer = DartAnalyzer();
      report = await analyzer.analyze(absoluteTargetPath, config);
    }
  } catch (e, stack) {
    stderr.writeln(Ansi.red('Fatal error during analysis: $e'));
    if (config.verbose) {
      stderr.writeln(stack);
    }
    exit(1);
  }

  final filteredFileReports = <FileReport>[];
  for (final fileReport in report.fileReports) {
    final normPath = p.normalize(fileReport.filePath);
    final modifiedLines = modifiedLinesByFile[normPath];
    if (modifiedLines == null) continue;

    final filteredFindings = fileReport.findings.where((f) => modifiedLines.contains(f.line)).toList();
    filteredFileReports.add(FileReport(
      filePath: fileReport.filePath,
      findings: filteredFindings,
      lineCount: fileReport.lineCount,
      analysisTimeMs: fileReport.analysisTimeMs,
    ));
  }

  final diffReport = ProjectReport(
    projectPath: report.projectPath,
    fileReports: filteredFileReports,
    totalAnalysisTimeMs: report.totalAnalysisTimeMs,
    analyzedAt: report.analyzedAt,
  );

  final reporter = switch (config.outputFormat) {
    OutputFormat.terminal => const TerminalReporter(),
    OutputFormat.json => const JsonReporter(),
    OutputFormat.markdown => const MarkdownReporter(),
    OutputFormat.prompt => const PromptReporter(),
  };

  final formattedOutput = reporter.format(diffReport);

  final outputPath = argResults['output'] as String?;
  if (outputPath != null) {
    try {
      final outputFile = File(outputPath);
      outputFile.writeAsStringSync(formattedOutput);
    } catch (e) {
      stderr.writeln(Ansi.red('Error: Failed to write output to "$outputPath". Error: $e'));
      exit(1);
    }
  } else {
    print(formattedOutput);
  }

  final failSeverityStr = argResults['fail-on-severity'] as String;
  if (failSeverityStr != 'none') {
    final failSeverity = Severity.values.firstWhere(
      (s) => s.name == failSeverityStr,
    );

    final triggerFindings = diffReport.allFindings.where(
      (f) => f.severity.isAtLeast(failSeverity),
    );

    if (triggerFindings.isNotEmpty) {
      exit(1);
    }
  }

  exit(0);
}
