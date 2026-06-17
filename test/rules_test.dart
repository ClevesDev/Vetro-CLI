import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:vetro/analyzers/dart/rules/cyclomatic_complexity_rule.dart';
import 'package:vetro/analyzers/dart/rules/intent_gap_rule.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/finding.dart';

void main() {
  group('Cyclomatic Complexity Rule', () {
    test('flags functions exceeding threshold', () {
      const config = RuleConfig(
        enabled: true,
        severity: Severity.warning,
        thresholds: {'max_complexity': 2.0},
      );
      final rule = CyclomaticComplexityRule(config: config);

      final source = '''
        void complexFunction(int a, int b) {
          if (a > 0) {
            if (b > 0) {
              print('both positive');
            }
          }
        }
      ''';
      final unit = parseString(content: source).unit;
      final findings = rule.analyze(unit, 'test.dart', source);

      expect(findings, hasLength(1));
      expect(findings.first.ruleId, equals('cyclomatic_complexity'));
      expect(findings.first.severity, equals(Severity.warning));
    });

    test('does not flag simple functions', () {
      const config = RuleConfig(
        enabled: true,
        severity: Severity.warning,
        thresholds: {'max_complexity': 10.0},
      );
      final rule = CyclomaticComplexityRule(config: config);

      final source = '''
        void simple() {
          print('hello');
        }
      ''';
      final unit = parseString(content: source).unit;
      final findings = rule.analyze(unit, 'test.dart', source);

      expect(findings, isEmpty);
    });
  });

  group('Intent Gap Rule', () {
    test('flags complex function without explanation comments', () {
      const config = RuleConfig(
        enabled: true,
        severity: Severity.info,
        thresholds: {'min_complexity': 2.0},
      );
      final rule = IntentGapRule(config: config);

      final source = '''
        void complexNoComment(int a) {
          if (a > 0) {
            print('positive');
          }
        }
      ''';
      final unit = parseString(content: source).unit;
      final findings = rule.analyze(unit, 'test.dart', source);

      expect(findings, hasLength(1));
      expect(findings.first.ruleId, equals('intent_gap'));
    });

    test('does not flag complex function with intent comment', () {
      const config = RuleConfig(
        enabled: true,
        severity: Severity.info,
        thresholds: {'min_complexity': 2.0},
      );
      final rule = IntentGapRule(config: config);

      final source = '''
        // This is necessary because we need to handle positive numbers differently.
        void complexWithComment(int a) {
          if (a > 0) {
            print('positive');
          }
        }
      ''';
      final unit = parseString(content: source).unit;
      final findings = rule.analyze(unit, 'test.dart', source);

      expect(findings, isEmpty);
    });
  });
}
