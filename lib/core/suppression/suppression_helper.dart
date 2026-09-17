/// Inline suppression directive parser and validator.
///
/// Supports line-level and file-level suppression directives across
/// Dart, TypeScript, and Python comments:
/// - `// vetro:ignore: <rule_id>`
/// - `// vetro:ignore: <rule_a>, <rule_b>`
/// - `// vetro:ignore: all` or `// vetro:ignore: *`
/// - `// vetro:ignore_file: <rule_id>`
/// - `/* vetro:ignore: <rule_id> */`
/// - `# vetro:ignore: <rule_id>`
library;

/// Holds parsed suppression directives for a single source file.
final class FileSuppression {
  const FileSuppression({
    this.fileIgnoredRules = const {},
    this.lineIgnoredRules = const {},
  });

  /// Parses suppression directives from [source] string.
  factory FileSuppression.fromSource(String source) {
    if (source.isEmpty) {
      return const FileSuppression();
    }

    final fileIgnoredRules = <String>{};
    final lineIgnoredRules = <int, Set<String>>{};

    final lines = source.split('\n');

    final ignoreFileRegex = RegExp(
      r'(?://|#|/\*)\s*vetro:ignore_file:\s*([^\n\r*\/]+|\*|all)',
      caseSensitive: false,
    );
    final ignoreLineRegex = RegExp(
      r'(?://|#|/\*)\s*vetro:ignore:\s*([^\n\r*\/]+|\*|all)',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      final lineNum = i + 1;
      final line = lines[i];

      // Check ignore_file
      final fileMatch = ignoreFileRegex.firstMatch(line);
      if (fileMatch != null) {
        final rulesStr = fileMatch.group(1);
        if (rulesStr != null) {
          _extractRules(rulesStr, fileIgnoredRules);
        }
      }

      // Check ignore (line-level)
      final lineMatch = ignoreLineRegex.firstMatch(line);
      if (lineMatch != null) {
        final rulesStr = lineMatch.group(1);
        if (rulesStr != null) {
          final targetRules = <String>{};
          _extractRules(rulesStr, targetRules);

          // 1. Same-line ignore
          lineIgnoredRules.putIfAbsent(lineNum, () => {}).addAll(targetRules);

          // 2. Next effective line: skip comments, blank lines, and annotations
          var nextLine = lineNum + 1;
          for (var j = i + 1; j < lines.length; j++) {
            final nextTrimmed = lines[j].trim();
            if (nextTrimmed.isEmpty) {
              continue;
            }
            if (nextTrimmed.startsWith('//') ||
                nextTrimmed.startsWith('/*') ||
                nextTrimmed.startsWith('*') ||
                nextTrimmed.startsWith('#')) {
              continue;
            }
            if (nextTrimmed.startsWith('@')) {
              lineIgnoredRules.putIfAbsent(j + 1, () => {}).addAll(targetRules);
              continue;
            }
            nextLine = j + 1;
            break;
          }

          lineIgnoredRules.putIfAbsent(nextLine, () => {}).addAll(targetRules);
          lineIgnoredRules.putIfAbsent(lineNum + 1, () => {}).addAll(targetRules);
        }
      }
    }

    return FileSuppression(
      fileIgnoredRules: fileIgnoredRules,
      lineIgnoredRules: lineIgnoredRules,
    );
  }

  /// Rules ignored for the entire file (normalized to lowercase).
  /// If it contains '*' or 'all', all rules are suppressed for this file.
  final Set<String> fileIgnoredRules;

  /// Rules ignored per line number (1-based line number -> set of lowercase rule IDs).
  final Map<int, Set<String>> lineIgnoredRules;

  /// Returns true if [ruleId] is suppressed at [line] (1-based).
  bool isSuppressed(String ruleId, int line) {
    final normalized = ruleId.toLowerCase().trim();

    // 1. File-level check
    if (fileIgnoredRules.contains('*') ||
        fileIgnoredRules.contains('all') ||
        fileIgnoredRules.contains(normalized)) {
      return true;
    }

    // 2. Line-level check on the same line
    final lineRules = lineIgnoredRules[line];
    if (lineRules != null) {
      if (lineRules.contains('*') ||
          lineRules.contains('all') ||
          lineRules.contains(normalized)) {
        return true;
      }
    }

    // 3. Fallback check on line - 1
    final prevLineRules = lineIgnoredRules[line - 1];
    if (prevLineRules != null) {
      if (prevLineRules.contains('*') ||
          prevLineRules.contains('all') ||
          prevLineRules.contains(normalized)) {
        return true;
      }
    }

    return false;
  }

  static void _extractRules(String raw, Set<String> targetSet) {
    var cleaned = raw.replaceAll('*/', '').trim();
    final commentIdx = cleaned.indexOf(RegExp(r'\s+(--|-)\s+'));
    if (commentIdx != -1) {
      cleaned = cleaned.substring(0, commentIdx).trim();
    }

    final parts = cleaned.split(',');
    for (final part in parts) {
      final token = part.trim().toLowerCase();
      final match = RegExp('^[a-zA-Z0-9_*]+').firstMatch(token);
      if (match != null) {
        final rule = match.group(0)!;
        if (rule.isNotEmpty) {
          targetSet.add(rule);
        }
      }
    }
  }
}
