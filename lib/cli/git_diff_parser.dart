import 'dart:io';
import 'package:path/path.dart' as p;

/// Parses git diff output to identify modified files and line numbers.
final class GitDiffParser {
  const GitDiffParser();

  /// Runs git diff and returns a map of absolute file paths to sets of modified line numbers.
  ///
  /// If [baseRef] is specified, it compares the working tree against that reference.
  /// If [baseRef] is null, it combines staged (`--cached`) and unstaged local changes compared to HEAD.
  Future<Map<String, Set<int>>> getModifiedLines(String targetPath, [String? baseRef]) async {
    final modified = <String, Set<int>>{};

    if (baseRef != null && baseRef.isNotEmpty) {
      final diff = await _runGitDiff(targetPath, [baseRef]);
      parseDiffOutput(diff, targetPath, modified);
    } else {
      // Combined staged and unstaged changes
      final unstagedDiff = await _runGitDiff(targetPath, []);
      parseDiffOutput(unstagedDiff, targetPath, modified);

      final stagedDiff = await _runGitDiff(targetPath, ['--cached']);
      parseDiffOutput(stagedDiff, targetPath, modified);
    }

    return modified;
  }

  Future<String> _runGitDiff(String targetPath, List<String> extraArgs) async {
    try {
      final args = ['diff', '-U0', ...extraArgs];
      final result = await Process.run('git', args, workingDirectory: targetPath);
      if (result.exitCode != 0) {
        // If not a git repo or git fails, return empty
        return '';
      }
      return result.stdout.toString();
    } catch (_) {
      return '';
    }
  }

  void parseDiffOutput(String diffOutput, String targetPath, Map<String, Set<int>> result) {
    if (diffOutput.isEmpty) return;

    final lines = diffOutput.split('\n');
    String? currentFile;

    for (final line in lines) {
      if (line.startsWith('+++ ')) {
        var relPath = line.substring(4).trim();
        // Remove quotes around the path if present
        if (relPath.startsWith('"') && relPath.endsWith('"')) {
          relPath = relPath.substring(1, relPath.length - 1);
        }
        if (relPath.startsWith('b/')) {
          final cleanPath = relPath.substring(2);
          currentFile = p.normalize(p.join(targetPath, cleanPath));
        }
      } else if (line.startsWith('@@ ') && currentFile != null) {
        // Line format: @@ -268,1 +268,2 @@ or @@ -268 +268 @@
        final parts = line.split(' ');
        if (parts.length < 4) continue;

        final newRange = parts[2]; // e.g. +268,2 or +268
        if (!newRange.startsWith('+')) continue;

        final rangeContent = newRange.substring(1); // remove '+'
        int startLine;
        int lineCount = 1;

        if (rangeContent.contains(',')) {
          final split = rangeContent.split(',');
          startLine = int.tryParse(split[0]) ?? 0;
          lineCount = int.tryParse(split[1]) ?? 0;
        } else {
          startLine = int.tryParse(rangeContent) ?? 0;
        }

        if (startLine > 0 && lineCount > 0) {
          final set = result.putIfAbsent(currentFile, () => {});
          for (var i = 0; i < lineCount; i++) {
            set.add(startLine + i);
          }
        }
      }
    }
  }
}
