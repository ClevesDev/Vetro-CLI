import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/analyzers/dart/rules/copy_mutate_rule.dart';
import 'package:vetro/analyzers/dart/rules/cyclomatic_complexity_rule.dart';
import 'package:vetro/analyzers/dart/rules/intent_gap_rule.dart';
import 'package:vetro/analyzers/dart/rules/semantic_duplication_rule.dart';
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
      const rule = CyclomaticComplexityRule(config: config);

      const source = '''
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
      const rule = CyclomaticComplexityRule(config: config);

      const source = '''
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
      const rule = IntentGapRule(config: config);

      const source = '''
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
      const rule = IntentGapRule(config: config);

      const source = '''
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

  group('Model Boilerplate Duplication Exclusion', () {
    test('isFlutterBoilerplate identifies model boilerplate methods', () {
      expect(isFlutterBoilerplate('User.copyWith'), isTrue);
      expect(isFlutterBoilerplate('User.toJson'), isTrue);
      expect(isFlutterBoilerplate('User.fromJson'), isTrue);
      expect(isFlutterBoilerplate('User.=='), isTrue);
      expect(isFlutterBoilerplate('User.hashCode'), isTrue);
      expect(isFlutterBoilerplate('User.toString'), isTrue);
      expect(isFlutterBoilerplate('User.props'), isTrue);
      expect(isFlutterBoilerplate('User.calculateTotal'), isFalse);
    });

    test('CopyMutateRule and SemanticDuplicationRule ignore copyWith methods', () async {
      const source1 = '''
        class UserState {
          final String name;
          final int age;
          final String email;
          final String address;
          final bool isActive;
          UserState({required this.name, required this.age, required this.email, required this.address, required this.isActive});

          UserState copyWith({String? name, int? age, String? email, String? address, bool? isActive}) {
            return UserState(
              name: name ?? this.name,
              age: age ?? this.age,
              email: email ?? this.email,
              address: address ?? this.address,
              isActive: isActive ?? this.isActive,
            );
          }
        }
      ''';

      const source2 = '''
        class ProductState {
          final String title;
          final int count;
          final String category;
          final String location;
          final bool isAvailable;
          ProductState({required this.title, required this.count, required this.category, required this.location, required this.isAvailable});

          ProductState copyWith({String? title, int? count, String? category, String? location, bool? isAvailable}) {
            return ProductState(
              title: title ?? this.title,
              count: count ?? this.count,
              category: category ?? this.category,
              location: location ?? this.location,
              isAvailable: isAvailable ?? this.isAvailable,
            );
          }
        }
      ''';

      final unit1 = parseString(content: source1).unit;
      final unit2 = parseString(content: source2).unit;

      final units = {'user.dart': unit1, 'product.dart': unit2};
      final sources = {'user.dart': source1, 'product.dart': source2};

      const copyRule = CopyMutateRule(config: RuleConfig(enabled: true));
      const semanticRule = SemanticDuplicationRule(config: RuleConfig(enabled: true));

      final copyFindings = await copyRule.analyzeProject(units, sources);
      final semanticFindings = await semanticRule.analyzeProject(units, sources);

      expect(copyFindings, isEmpty);
      expect(semanticFindings, isEmpty);
    });
  });
}
