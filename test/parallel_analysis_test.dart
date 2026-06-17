import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:vetro/analyzers/dart/dart_analyzer.dart';
import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/analyzers/dart/rules/copy_mutate_rule.dart';
import 'package:vetro/analyzers/dart/rules/semantic_duplication_rule.dart';

void main() {
  group('Auto-Exclude Generated Code', () {
    late Directory tempDir;

    setUp(() {
      // Create temp dir inside workspace test folder
      tempDir = Directory('test/temp_auto_exclude_test')..createSync(recursive: true);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('excludes files with auto-generated headers when option is enabled', () async {
      final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync(recursive: true);
      
      final normalFile = File(p.join(libDir.path, 'normal.dart'));
      normalFile.writeAsStringSync('''
        void foo() {
          print('Hello World');
        }
      ''');

      final generatedFile = File(p.join(libDir.path, 'generated.g.dart'));
      generatedFile.writeAsStringSync('''
        // GENERATED CODE - DO NOT MODIFY BY HAND
        // Any modification will be lost
        void generatedFunction() {
          print('I am generated');
        }
      ''');

      final analyzer = DartAnalyzer();

      // Use default include (which is ['lib/*.dart', 'lib/**/*.dart'])
      final config = VetroConfig(
        autoExcludeGenerated: true,
      );

      final report = await analyzer.analyze(tempDir.absolute.path, config);
      final analyzedFiles = report.fileReports.map((r) => p.basename(r.filePath)).toList();

      expect(analyzedFiles, contains('normal.dart'));
      expect(analyzedFiles, isNot(contains('generated.g.dart')));
    });

    test('includes files with auto-generated headers when option is disabled', () async {
      final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync(recursive: true);

      final normalFile = File(p.join(libDir.path, 'normal.dart'));
      normalFile.writeAsStringSync('''
        void foo() {
          print('Hello World');
        }
      ''');

      final generatedFile = File(p.join(libDir.path, 'generated.dart'));
      generatedFile.writeAsStringSync('''
        // GENERATED CODE - DO NOT MODIFY BY HAND
        void generatedFunction() {
          print('I am generated');
        }
      ''');

      final analyzer = DartAnalyzer();

      // Use default include, but disable auto-exclude
      final config = VetroConfig(
        autoExcludeGenerated: false,
      );

      final report = await analyzer.analyze(tempDir.absolute.path, config);
      final analyzedFiles = report.fileReports.map((r) => p.basename(r.filePath)).toList();

      expect(analyzedFiles, contains('normal.dart'));
      expect(analyzedFiles, contains('generated.dart'));
    });
  });

  group('Parallel vs Sequential Analysis Determinism', () {
    test('produces exactly the same findings in sequential and parallel modes', () async {
      // We will generate a mock AST structure of functions.
      // To test the parallel logic of CopyMutateRule and SemanticDuplicationRule:
      // We can construct a project model and call rule.analyzeProject directly!
      
      // Let's create two similar functions (making them larger to ensure nodeCount > 40)
      final String sourceBase = '''
        void functionBase(int x, int y) {
          final a = x + y;
          final b = a * 2;
          final c = b - 5;
          final d = c + 10;
          final e = d * 3;
          final f = e - 1;
          print(a);
          print(b);
          print(c);
          print(d);
          print(e);
          print(f);
          if (f > 100) {
            print('large');
          } else {
            print('small');
          }
        }
      ''';
      
      final String sourceCopy = '''
        void functionCopy(int x, int y) {
          final a = x + y;
          final b = a * 2;
          final c = b - 5;
          final d = c + 10;
          final e = d * 3;
          final f = e - 2; // Mutated slightly
          print(a);
          print(b);
          print(c);
          print(d);
          print(e);
          print(f);
          if (f > 100) {
            print('large');
          } else {
            print('small');
          }
        }
      ''';

      // We need to generate unique files/functions to reach N >= 100 for parallel mode.
      // Let's construct a list of distinct functions.
      final units = <String, CompilationUnit>{};
      final sources = <String, String>{};

      // Add the duplicate pair
      final pathBase = '/home/dimas/development/Vetro/lib/base.dart';
      final pathCopy = '/home/dimas/development/Vetro/lib/copy.dart';
      units[pathBase] = parseString(content: sourceBase).unit;
      sources[pathBase] = sourceBase;
      units[pathCopy] = parseString(content: sourceCopy).unit;
      sources[pathCopy] = sourceCopy;

      // Add 110 unique functions to exceed the N >= 100 threshold
      for (var i = 0; i < 110; i++) {
        final uniqueSource = '''
          void uniqueFunction\$i() {
            final val\$i = \$i;
            final other\$i = val\$i + 1;
            print('unique' + other\$i.toString());
          }
        ''';
        final path = '/home/dimas/development/Vetro/lib/unique_\$i.dart';
        units[path] = parseString(content: uniqueSource).unit;
        sources[path] = uniqueSource;
      }

      // 1. Test CopyMutateRule
      const copyMutateRule = CopyMutateRule(
        config: RuleConfig(
          enabled: true,
          thresholds: {'similarity': 0.70},
        ),
      );

      // We run the parallel version (since N >= 100)
      final parallelCopyMutateFindings = await copyMutateRule.analyzeProject(units, sources);

      // Now we mock sequential execution by running it on just the duplicate pair (N < 100)
      final smallUnits = {pathBase: units[pathBase]!, pathCopy: units[pathCopy]!};
      final smallSources = {pathBase: sources[pathBase]!, pathCopy: sources[pathCopy]!};
      final seqCopyMutateFindings = await copyMutateRule.analyzeProject(smallUnits, smallSources);

      expect(parallelCopyMutateFindings.length, equals(seqCopyMutateFindings.length));
      expect(parallelCopyMutateFindings.first.message, equals(seqCopyMutateFindings.first.message));

      // 2. Test SemanticDuplicationRule
      const semDupRule = SemanticDuplicationRule(
        config: RuleConfig(
          enabled: true,
          thresholds: {'similarity': 0.80},
        ),
      );

      final parallelSemDupFindings = await semDupRule.analyzeProject(units, sources);
      final seqSemDupFindings = await semDupRule.analyzeProject(smallUnits, smallSources);

      expect(parallelSemDupFindings.length, equals(seqSemDupFindings.length));
      expect(parallelSemDupFindings.first.message, equals(seqSemDupFindings.first.message));
    });
  });

  group('Boilerplate and Annotation Filtering', () {
    test('filters out methods annotated with @riverpod or simple @override', () async {
      final source = '''
        class MyWidget {
          @override
          void simpleOverride() {
            // Very simple
            print('simple');
          }

          @override
          void complexOverride() {
            // Complex override
            final a = 1;
            final b = 2;
            final c = a + b;
            print(c);
            if (c > 0) {
              print('yes');
            } else {
              print('no');
            }
          }

          @riverpod
          void riverpodMethod() {
            final a = 1;
            final b = 2;
            print(a + b);
          }
        }
      ''';

      final unit = parseString(content: source).unit;
      final bodies = extractAllBodies(unit, 'test.dart');

      // simpleOverride should be boilerplate (annotated with @override and < 25 nodes)
      final simpleOverride = bodies.firstWhere((b) => b.name.contains('simpleOverride'));
      expect(isBoilerplateDeclaration(simpleOverride.declaration), isTrue);

      // complexOverride should NOT be boilerplate (annotated with @override but >= 25 nodes)
      final complexOverride = bodies.firstWhere((b) => b.name.contains('complexOverride'));
      expect(isBoilerplateDeclaration(complexOverride.declaration), isFalse);

      // riverpodMethod should be boilerplate (annotated with @riverpod)
      final riverpodMethod = bodies.firstWhere((b) => b.name.contains('riverpodMethod'));
      expect(isBoilerplateDeclaration(riverpodMethod.declaration), isTrue);
    });
  });
}
