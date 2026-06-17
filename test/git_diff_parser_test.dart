import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:vetro/cli/git_diff_parser.dart';

void main() {
  group('GitDiffParser', () {
    const parser = GitDiffParser();
    final targetPath = p.normalize('/dummy/project');

    test('returns empty map for empty diff output', () {
      final result = <String, Set<int>>{};
      parser.parseDiffOutput('', targetPath, result);
      expect(result, isEmpty);
    });

    test('parses single line changes correctly', () {
      final result = <String, Set<int>>{};
      final diff = '''
diff --git a/lib/file.dart b/lib/file.dart
index 123456..789012 100644
--- a/lib/file.dart
+++ b/lib/file.dart
@@ -10 +10 @@
-old line
+new line
''';
      parser.parseDiffOutput(diff, targetPath, result);
      
      final expectedPath = p.normalize('$targetPath/lib/file.dart');
      expect(result.keys, contains(expectedPath));
      expect(result[expectedPath], equals({10}));
    });

    test('parses multi-line changes correctly', () {
      final result = <String, Set<int>>{};
      final diff = '''
diff --git a/lib/src/helper.dart b/lib/src/helper.dart
index abcdef..ffffff 100644
--- a/lib/src/helper.dart
+++ b/lib/src/helper.dart
@@ -25,1 +25,3 @@
-  print('old');
+  print('new 1');
+  print('new 2');
+  print('new 3');
''';
      parser.parseDiffOutput(diff, targetPath, result);

      final expectedPath = p.normalize('$targetPath/lib/src/helper.dart');
      expect(result.keys, contains(expectedPath));
      expect(result[expectedPath], equals({25, 26, 27}));
    });

    test('handles multiple files and hunks in one diff', () {
      final result = <String, Set<int>>{};
      final diff = '''
diff --git a/lib/a.dart b/lib/a.dart
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -5,2 +5,1 @@
-  print('a');
-  print('b');
+  print('ab');
@@ -20 +20,4 @@
+  // added lines
+  int x = 1;
+  int y = 2;
+  return x + y;
diff --git a/lib/b.dart b/lib/b.dart
--- a/lib/b.dart
+++ b/lib/b.dart
@@ -100,5 +100,2 @@
-  x;
-  y;
-  z;
+  a;
+  b;
''';
      parser.parseDiffOutput(diff, targetPath, result);

      final pathA = p.normalize('$targetPath/lib/a.dart');
      final pathB = p.normalize('$targetPath/lib/b.dart');

      expect(result.keys, containsAll([pathA, pathB]));
      expect(result[pathA], equals({5, 20, 21, 22, 23}));
      expect(result[pathB], equals({100, 101}));
    });

    test('handles quoted file paths', () {
      final result = <String, Set<int>>{};
      final diff = '''
diff --git "a/lib/space file.dart" "b/lib/space file.dart"
--- "a/lib/space file.dart"
+++ "b/lib/space file.dart"
@@ -1 +1 @@
+// space file change
''';
      parser.parseDiffOutput(diff, targetPath, result);

      final expectedPath = p.normalize('$targetPath/lib/space file.dart');
      expect(result.keys, contains(expectedPath));
      expect(result[expectedPath], equals({1}));
    });
  });
}
