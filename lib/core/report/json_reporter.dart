/// JSON reporter for machine-readable Vetro output.
///
/// Produces structured JSON suitable for CI/CD pipelines,
/// dashboards, and programmatic consumption.
library;

import 'dart:convert';

import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/report/reporter.dart';

/// Formats a [ProjectReport] as pretty-printed JSON.
///
/// Output schema:
/// ```json
/// {
///   "version": "0.1.0",
///   "project_path": "/path/to/project",
///   "analyzed_at": "2026-06-15T21:22:54Z",
///   "summary": {
///     "file_count": 127,
///     "line_count": 8432,
///     "ai_debt_score": 74,
///     "findings_by_severity": { "error": 2, "warning": 14, "info": 5 }
///   },
///   "findings": [ ... ]
/// }
/// ```
final class JsonReporter extends Reporter {
  const JsonReporter();

  /// The Vetro version included in the report metadata.
  static const String _version = '0.1.0';

  @override
  String format(ProjectReport report) {
    final data = <String, Object>{
      'version': _version,
      'project_path': report.projectPath,
      'analyzed_at': report.analyzedAt.toUtc().toIso8601String(),
      'summary': _buildSummary(report),
      'findings': _buildFindings(report),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  Map<String, Object> _buildSummary(ProjectReport report) => {
        'file_count': report.fileCount,
        'line_count': report.totalLines,
        'ai_debt_score': report.aiDebtScore,
        'analysis_time_ms': report.totalAnalysisTimeMs,
        'findings_by_severity': {
          'error': report.countBySeverity(Severity.error),
          'warning': report.countBySeverity(Severity.warning),
          'info': report.countBySeverity(Severity.info),
        },
      };

  List<Map<String, Object>> _buildFindings(ProjectReport report) => [
        for (final finding in report.allFindings)
          _findingToMap(finding),
      ];

  Map<String, Object> _findingToMap(Finding finding) {
    final map = <String, Object>{
      'rule_id': finding.ruleId,
      'rule_name': finding.ruleName,
      'severity': finding.severity.name,
      'file': finding.filePath,
      'line': finding.line,
      'column': finding.column,
      'message': finding.message,
    };

    if (finding.endLine != null) {
      map['end_line'] = finding.endLine!;
    }
    if (finding.endColumn != null) {
      map['end_column'] = finding.endColumn!;
    }
    if (finding.evidence.isNotEmpty) {
      map['evidence'] = finding.evidence;
    }

    return map;
  }
}
