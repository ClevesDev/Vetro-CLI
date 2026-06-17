/// Core models for Vetro analysis findings.
///
/// Every finding is a measurable, reproducible fact about the code —
/// never an opinion. The severity levels reflect objective thresholds,
/// not subjective judgment.
library;

/// The severity of an analysis finding.
///
/// Semantics are strict and unambiguous:
/// - [error]: The code is objectively problematic. Blocks CI.
/// - [warning]: The code is likely problematic. Should be addressed.
/// - [info]: The code merits human review. May be intentional.
enum Severity {
  info,
  warning,
  error;

  /// Returns true if this severity is equal to or greater than [other].
  bool isAtLeast(Severity other) => index >= other.index;

  @override
  String toString() => name;
}

/// A single finding produced by a Rule.
///
/// Each finding is backed by a deterministic metric — it can be
/// independently verified by inspecting the referenced source location
/// and applying the rule's mathematical formula.
final class Finding {
  const Finding({
    required this.ruleId,
    required this.ruleName,
    required this.severity,
    required this.filePath,
    required this.line,
    required this.message,
    this.column = 0,
    this.endLine,
    this.endColumn,
    this.evidence = const {},
  });

  /// The unique identifier of the rule that produced this finding.
  /// Example: `'semantic_duplication'`
  final String ruleId;

  /// Human-readable name of the rule.
  /// Example: `'Semantic Duplication'`
  final String ruleName;

  /// The severity level of this finding.
  final Severity severity;

  /// Absolute path to the file containing the finding.
  final String filePath;

  /// 1-based line number where the finding starts.
  final int line;

  /// 1-based column number where the finding starts (0 if unknown).
  final int column;

  /// 1-based line number where the finding ends (null if single-line).
  final int? endLine;

  /// 1-based column number where the finding ends (null if unknown).
  final int? endColumn;

  /// Human-readable description of what was found.
  final String message;

  /// Quantitative evidence backing this finding.
  ///
  /// Keys are metric names, values are their measurements.
  /// Example: `{'similarity': '91%', 'compared_to': 'lib/utils.dart:45'}`
  final Map<String, String> evidence;

  @override
  String toString() =>
      '[$severity] $filePath:$line — $ruleName: $message';
}

/// Analysis results for a single file.
final class FileReport {
  const FileReport({
    required this.filePath,
    required this.findings,
    required this.lineCount,
    required this.analysisTimeMs,
  });

  /// Absolute path to the analyzed file.
  final String filePath;

  /// All findings discovered in this file.
  final List<Finding> findings;

  /// Total number of lines in the file.
  final int lineCount;

  /// Time spent analyzing this file, in milliseconds.
  final int analysisTimeMs;

  /// Number of findings at or above the given severity.
  int countBySeverity(Severity severity) =>
      findings.where((f) => f.severity == severity).length;

  /// True if this file has no findings.
  bool get isClean => findings.isEmpty;
}

/// Aggregated analysis results for an entire project.
final class ProjectReport {
  const ProjectReport({
    required this.projectPath,
    required this.fileReports,
    required this.totalAnalysisTimeMs,
    required this.analyzedAt,
  });

  /// Root path of the analyzed project.
  final String projectPath;

  /// Per-file reports.
  final List<FileReport> fileReports;

  /// Total analysis time in milliseconds.
  final int totalAnalysisTimeMs;

  /// Timestamp when analysis was performed.
  final DateTime analyzedAt;

  /// All findings across all files.
  List<Finding> get allFindings =>
      fileReports.expand((r) => r.findings).toList();

  /// Total number of files analyzed.
  int get fileCount => fileReports.length;

  /// Total lines of code analyzed.
  int get totalLines =>
      fileReports.fold(0, (sum, r) => sum + r.lineCount);

  /// Count of findings by severity.
  int countBySeverity(Severity severity) =>
      allFindings.where((f) => f.severity == severity).length;

  /// The AI Debt Score: 0-100 where 100 is pristine.
  ///
  /// Formula:
  ///   score = 100 - (weighted_penalty)
  ///   where weighted_penalty = Σ(finding_weight × severity_multiplier)
  ///   normalized by total lines of code.
  ///
  /// Severity multipliers: error=5, warning=2, info=0.5
  /// Each finding has a base weight of 1.
  /// The penalty is capped at 100 (score floor is 0).
  int get aiDebtScore {
    if (totalLines == 0) return 100;

    const severityMultipliers = {
      Severity.error: 5.0,
      Severity.warning: 2.0,
      Severity.info: 0.5,
    };

    var totalPenalty = 0.0;
    for (final finding in allFindings) {
      totalPenalty += severityMultipliers[finding.severity] ?? 1.0;
    }

    // Normalize by lines of code (per 1000 LOC).
    final normalizedPenalty = (totalPenalty / totalLines) * 1000;

    // Clamp to 0-100.
    final score = (100 - normalizedPenalty).clamp(0, 100);
    return score.round();
  }
}
