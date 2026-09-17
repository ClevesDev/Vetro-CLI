import 'package:test/test.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/suppression/suppression_helper.dart';

void main() {
  group('FileSuppression', () {
    test('suppresses rule on line following // vetro:ignore: rule_id', () {
      const source = '''
void cleanFunction() {}

// vetro:ignore: halstead_complexity
void complexFunction() {
  var x = 1;
}
''';
      final suppression = FileSuppression.fromSource(source);
      expect(suppression.isSuppressed('halstead_complexity', 4), isTrue);
      expect(suppression.isSuppressed('halstead_complexity', 5), isTrue);
      expect(suppression.isSuppressed('cyclomatic_complexity', 4), isFalse);
      expect(suppression.isSuppressed('halstead_complexity', 1), isFalse);
    });

    test('suppresses rule on same line inline comment', () {
      const source = '''
final dynamicWidget = Container(); // vetro:ignore: missing_const_constructors
''';
      final suppression = FileSuppression.fromSource(source);
      expect(
        suppression.isSuppressed('missing_const_constructors', 1),
        isTrue,
      );
      expect(suppression.isSuppressed('other_rule', 1), isFalse);
    });

    test('suppresses across annotations preceding declaration', () {
      const source = '''
// vetro:ignore: business_logic_in_ui
@override
Widget build(BuildContext context) {
  return Container();
}
''';
      final suppression = FileSuppression.fromSource(source);
      expect(suppression.isSuppressed('business_logic_in_ui', 3), isTrue);
      expect(suppression.isSuppressed('business_logic_in_ui', 2), isTrue);
    });

    test('suppresses multiple comma-separated rules and ignores with descriptions', () {
      const source = '''
// vetro:ignore: cognitive_complexity, cyclomatic_complexity - needed for legacy parser
void complexParsing() {}
''';
      final suppression = FileSuppression.fromSource(source);
      expect(suppression.isSuppressed('cognitive_complexity', 2), isTrue);
      expect(suppression.isSuppressed('cyclomatic_complexity', 2), isTrue);
      expect(suppression.isSuppressed('intent_gap', 2), isFalse);
    });

    test('supports wildcard all or *', () {
      const source = '''
// vetro:ignore: all
void everythingGoes() {}
''';
      final suppression = FileSuppression.fromSource(source);
      expect(suppression.isSuppressed('anything', 2), isTrue);
      expect(suppression.isSuppressed('cognitive_complexity', 2), isTrue);
    });

    test('suppresses entire file with vetro:ignore_file', () {
      const source = '''
// vetro:ignore_file: semantic_duplication
class A {
  void foo() {}
}

class B {
  void foo() {}
}
''';
      final suppression = FileSuppression.fromSource(source);
      expect(suppression.isSuppressed('semantic_duplication', 2), isTrue);
      expect(suppression.isSuppressed('semantic_duplication', 6), isTrue);
      expect(suppression.isSuppressed('other_rule', 2), isFalse);
    });

    test('supports Python (#) and block comment (/* */) styles', () {
      const pySource = '''
# vetro:ignore: py_cognitive_complexity
def compute():
    pass
''';
      final pySuppression = FileSuppression.fromSource(pySource);
      expect(pySuppression.isSuppressed('py_cognitive_complexity', 2), isTrue);

      const blockSource = '''
/* vetro:ignore: halstead_complexity */
function doWork() {}
''';
      final blockSuppression = FileSuppression.fromSource(blockSource);
      expect(blockSuppression.isSuppressed('halstead_complexity', 2), isTrue);
    });
  });

  group('RuleConfig & VetroConfig exclude', () {
    test('parses per-rule exclude and direct thresholds from YAML', () {
      const yaml = '''
vetro:
  rules:
    intent_gap:
      enabled: true
      min_complexity: 8
      exclude:
        - "lib/main.dart"
        - "**/*.g.dart"
''';
      final config = VetroConfig.fromYaml(yaml);
      final ruleConf = config.ruleConfig('intent_gap');
      expect(ruleConf.enabled, isTrue);
      expect(ruleConf.exclude, contains('lib/main.dart'));
      expect(ruleConf.exclude, contains('**/*.g.dart'));
      expect(ruleConf.threshold('min_complexity'), equals(8.0));
    });
  });

  group('FileReport & ProjectReport suppression metrics', () {
    test('tracks suppressedFindings and excluded from active findings', () {
      const active = Finding(
        ruleId: 'empty_catch',
        ruleName: 'Empty Catch',
        severity: Severity.warning,
        filePath: '/test/foo.dart',
        line: 10,
        message: 'Empty catch',
      );
      const suppressed = Finding(
        ruleId: 'intent_gap',
        ruleName: 'Intent Gap',
        severity: Severity.info,
        filePath: '/test/foo.dart',
        line: 20,
        message: 'Intent gap',
      );

      const fileReport = FileReport(
        filePath: '/test/foo.dart',
        findings: [active],
        suppressedFindings: [suppressed],
        lineCount: 50,
        analysisTimeMs: 10,
      );

      final projectReport = ProjectReport(
        projectPath: '/test',
        fileReports: [fileReport],
        totalAnalysisTimeMs: 10,
        analyzedAt: DateTime.now(),
      );

      expect(projectReport.allFindings.length, equals(1));
      expect(projectReport.suppressedCount, equals(1));
      expect(projectReport.countBySeverity(Severity.info), equals(0));
      expect(projectReport.countBySeverity(Severity.warning), equals(1));
    });
  });
}
