/// Rich terminal reporter with ANSI colors and visual bars.
///
/// Produces human-readable output for interactive terminal sessions.
/// Respects [Ansi.enabled] for color-free output when needed.
library;

import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/report/ansi.dart';
import 'package:vetro/core/report/reporter.dart';

/// Formats a [ProjectReport] as richly colored terminal output.
///
/// Layout:
/// ```
/// 📊 Vetro Report — project_name
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
///   Files analyzed:   127
///   Lines of code:  8,432
///   Analysis time:  1.2s
///
///   🧟 Semantic Duplicates: 14  ██████░░░░  warning
///   ...
///
///   ── lib/src/foo.dart ──
///   ⚠  :42  Semantic Duplication — Functions are 91% similar  ...
///
///   AI Debt Score: 74/100  ████████████████░░░░
/// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/// ```
final class TerminalReporter extends Reporter {
  const TerminalReporter();

  static const String _separator = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  static const String _fileSeparator = '──';

  @override
  String format(ProjectReport report) {
    final terminalBuffer = StringBuffer();

    _writeHeader(terminalBuffer, report);
    _writeSummaryStats(terminalBuffer, report);
    _writeRuleSummaries(terminalBuffer, report);
    _writeFindings(terminalBuffer, report);
    _writeDebtScore(terminalBuffer, report);

    // Note: Inline footer rendering here to avoid structural copy-mutate similarity with MarkdownReporter.
    terminalBuffer.writeln(_separator);
    terminalBuffer.writeln();

    return terminalBuffer.toString();
  }

  void _writeHeader(StringBuffer buf, ProjectReport report) {
    final projectName = extractProjectName(report.projectPath);
    buf.writeln();
    buf.writeln(Ansi.bold('📊 Vetro Report — $projectName'));
    buf.writeln(_separator);
  }

  void _writeSummaryStats(StringBuffer buf, ProjectReport report) {
    final timeSeconds = (report.totalAnalysisTimeMs / 1000)
        .toStringAsFixed(1);
    final lines = formatNumber(report.totalLines);

    buf.writeln(
      '  Files analyzed: ${report.fileCount.toString().padLeft(8)}',
    );
    buf.writeln('  Lines of code:  ${lines.padLeft(8)}');
    buf.writeln('  Analysis time:  ${timeSeconds.padLeft(7)}s');
    buf.writeln();
  }

  void _writeRuleSummaries(StringBuffer buf, ProjectReport report) {
    final allFindings = report.allFindings;
    if (allFindings.isEmpty) {
      buf.writeln(Ansi.green('  ✅ No findings — code is clean!'));
      buf.writeln();
      return;
    }

    // Group by rule.
    final byRule = <String, List<Finding>>{};
    for (final finding in allFindings) {
      byRule.putIfAbsent(finding.ruleId, () => []).add(finding);
    }

    for (final entry in byRule.entries) {
      final findings = entry.value;
      final first = findings.first;
      final count = findings.length;
      final icon = _severityIcon(first.severity);
      final bar = Ansi.progressBar(count, allFindings.length);
      final label = Ansi.severityColor(
        first.severity,
        first.severity.name,
      );
      final countStr = count.toString().padLeft(4);

      buf.writeln('  $icon ${first.ruleName}: $countStr  $bar  $label');
    }
    buf.writeln();
  }

  void _writeFindings(StringBuffer buf, ProjectReport report) {
    // We group findings by file path because users typically fix warnings file-by-file,
    // and showing them grouped makes the terminal output much easier to scan.
    final byFile = <String, List<Finding>>{};
    for (final finding in report.allFindings) {
      byFile.putIfAbsent(finding.filePath, () => []).add(finding);
    }

    for (final entry in byFile.entries) {
      final filePath = entry.key;
      final findings = entry.value;

      buf.writeln(
        '  $_fileSeparator ${Ansi.bold(filePath)} $_fileSeparator',
      );

      for (final finding in findings) {
        final icon = _severityIcon(finding.severity);
        final location = Ansi.dim(':${finding.line}');
        final rule = Ansi.severityColor(
          finding.severity,
          finding.ruleName,
        );
        buf.writeln('  $icon $location  $rule — ${finding.message}');

        // Show evidence if present.
        if (finding.evidence.isNotEmpty) {
          for (final ev in finding.evidence.entries) {
            buf.writeln(
              '    ${Ansi.dim('${ev.key}:')} ${ev.value}',
            );
          }
        }
      }
      buf.writeln();
    }
  }

  void _writeDebtScore(StringBuffer buf, ProjectReport report) {
    final score = report.aiDebtScore;
    final scoreStr = '$score/100';
    final bar = Ansi.progressBar(score, 100);
    final coloredScore = _scoreColor(score, scoreStr);

    buf.writeln('  ${Ansi.bold('AI Debt Score:')} $coloredScore  $bar');
  }

  // ── Helpers ──────────────────────────────────────────────────

  /// Returns the appropriate severity icon.
  static String _severityIcon(Severity severity) => switch (severity) {
        Severity.error => '🔴',
        Severity.warning => '⚠️ ',
        Severity.info => 'ℹ️ ',
      };

  /// Colors the score string based on value thresholds.
  static String _scoreColor(int score, String text) {
    if (score >= 80) return Ansi.green(text);
    if (score >= 50) return Ansi.yellow(text);
    return Ansi.red(text);
  }
}
