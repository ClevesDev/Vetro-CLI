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

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message and usage info.',
    )
    ..addOption(
      'format',
      abbr: 'f',
      allowed: ['terminal', 'json', 'markdown'],
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

  if (argResults['help'] as bool) {
    print('Vetro — AI Code Debt Scanner');
    print('Usage: vetro [options] <project_path>');
    print('');
    print(parser.usage);
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

  config = VetroConfig(
    include: config.include,
    exclude: excludeList,
    rules: config.rules,
    outputFormat: outputFormat,
    color: useColor,
    verbose: config.verbose || verboseOption,
  );

  if (config.verbose) {
    print(Ansi.dim('Loading analyzer rules registry...'));
  }

  final analyzer = DartAnalyzer();

  if (config.verbose) {
    print(Ansi.dim('Starting analysis of "$absoluteTargetPath"...'));
  } else if (config.outputFormat == OutputFormat.terminal) {
    print('Analyzing codebase...');
  }

  ProjectReport report;
  try {
    report = await analyzer.analyze(absoluteTargetPath, config);
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
