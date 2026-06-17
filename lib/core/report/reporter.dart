/// Abstract reporter interface for Vetro analysis output.
///
/// Each concrete reporter transforms a [ProjectReport] into a
/// string in a specific format (terminal, JSON, markdown, etc.).
/// Reporters are pure formatters — they perform no IO themselves.
library;

import 'package:vetro/core/models/finding.dart';

/// Contract for formatting a [ProjectReport] into a string.
///
/// Implementations must be stateless: given the same report,
/// [format] always returns the same string.
abstract class Reporter {
  const Reporter();

  /// Transforms [report] into a formatted string ready for output.
  String format(ProjectReport report);

  /// Extracts the last path segment as the project name.
  String extractProjectName(String projectPath) {
    final segments = projectPath.split('/').where(
      (s) => s.isNotEmpty,
    );
    return segments.isEmpty ? projectPath : segments.last;
  }

  /// Formats an integer with comma-separated thousands.
  String formatNumber(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );
}
