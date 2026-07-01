import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:vetro/analyzers/dart/rules/performance_media_query_rule.dart';
import 'package:vetro/analyzers/dart/rules/business_logic_in_ui_rule.dart';
import 'package:vetro/analyzers/dart/rules/misplaced_layout_constraints_rule.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/project_context.dart';

void main() {
  group('PerformanceMediaQueryRule', () {
    const config = RuleConfig(enabled: true, severity: Severity.warning);
    final rule = PerformanceMediaQueryRule(config: config);

    test('does not flag MediaQuery.of(context).size if Flutter version < 3.10.0', () {
      final projectContext = ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: const Version(3, 7, 0),
      );

      final source = '''
        class MyWidget extends StatelessWidget {
          @override
          Widget build(BuildContext context) {
            final size = MediaQuery.of(context).size;
            return Container(width: size.width);
          }
        }
      ''';

      final unit = parseString(content: source).unit;
      final fileContext = FileContext(
        filePath: 'lib/my_widget.dart',
        sourceCode: source,
        functions: const [],
        classes: const [],
        imports: const [],
        projectContext: projectContext,
        nativeAst: unit,
      );

      final findings = rule.analyzeFile(fileContext);
      expect(findings, isEmpty);
    });

    test('flags MediaQuery.of(context).size if Flutter version >= 3.10.0', () {
      final projectContext = ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: const Version(3, 22, 0),
      );

      final source = '''
        class MyWidget extends StatelessWidget {
          @override
          Widget build(BuildContext context) {
            final size = MediaQuery.of(context).size;
            return Container(width: size.width);
          }
        }
      ''';

      final unit = parseString(content: source).unit;
      final fileContext = FileContext(
        filePath: 'lib/my_widget.dart',
        sourceCode: source,
        functions: const [],
        classes: const [],
        imports: const [],
        projectContext: projectContext,
        nativeAst: unit,
      );

      final findings = rule.analyzeFile(fileContext);
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, equals('performance_media_query'));
      expect(findings.first.severity, equals(Severity.warning));
    });

    test('does not flag MediaQuery.sizeOf(context) in modern Flutter projects', () {
      final projectContext = ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: const Version(3, 44, 0),
      );

      final source = '''
        class MyWidget extends StatelessWidget {
          @override
          Widget build(BuildContext context) {
            final width = MediaQuery.sizeOf(context).width;
            return Container(width: width);
          }
        }
      ''';

      final unit = parseString(content: source).unit;
      final fileContext = FileContext(
        filePath: 'lib/my_widget.dart',
        sourceCode: source,
        functions: const [],
        classes: const [],
        imports: const [],
        projectContext: projectContext,
        nativeAst: unit,
      );

      final findings = rule.analyzeFile(fileContext);
      expect(findings, isEmpty);
    });
  });

  group('BusinessLogicInUiRule', () {
    const config = RuleConfig(enabled: true, severity: Severity.error);
    final rule = BusinessLogicInUiRule(config: config);

    test('flags service, repository, and controller instantiation inside build method', () {
      final projectContext = ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: const Version(3, 44, 0),
      );

      final source = '''
        class MyWidget extends StatelessWidget {
          @override
          Widget build(BuildContext context) {
            final authService = AuthenticationService();
            final controller = UserController();
            return Container();
          }
        }
      ''';

      final unit = parseString(content: source).unit;
      final fileContext = FileContext(
        filePath: 'lib/my_widget.dart',
        sourceCode: source,
        functions: const [],
        classes: const [],
        imports: const [],
        projectContext: projectContext,
        nativeAst: unit,
      );

      final findings = rule.analyzeFile(fileContext);
      expect(findings, hasLength(2));
      expect(findings[0].evidence['violation_type'], equals('business_instance_creation'));
      expect(findings[1].evidence['violation_type'], equals('business_instance_creation'));
    });

    test('flags await expressions inside build method', () {
      final projectContext = ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: const Version(3, 44, 0),
      );

      final source = '''
        class MyWidget extends StatelessWidget {
          @override
          Widget build(BuildContext context) async {
            final data = await fetchSomeData();
            return Text(data);
          }
        }
      ''';

      final unit = parseString(content: source).unit;
      final fileContext = FileContext(
        filePath: 'lib/my_widget.dart',
        sourceCode: source,
        functions: const [],
        classes: const [],
        imports: const [],
        projectContext: projectContext,
        nativeAst: unit,
      );

      final findings = rule.analyzeFile(fileContext);
      expect(findings, hasLength(1));
      expect(findings.first.evidence['violation_type'], equals('await_in_build'));
    });

    test('flags inline network calls inside build method', () {
      final projectContext = ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: const Version(3, 44, 0),
      );

      final source = '''
        class MyWidget extends StatelessWidget {
          @override
          Widget build(BuildContext context) {
            http.get(Uri.parse('https://api.example.com'));
            return Container();
          }
        }
      ''';

      final unit = parseString(content: source).unit;
      final fileContext = FileContext(
        filePath: 'lib/my_widget.dart',
        sourceCode: source,
        functions: const [],
        classes: const [],
        imports: const [],
        projectContext: projectContext,
        nativeAst: unit,
      );

      final findings = rule.analyzeFile(fileContext);
      expect(findings, hasLength(1));
      expect(findings.first.evidence['violation_type'], equals('network_request_in_build'));
    });

    test('does not flag private controller variables or native Flutter UI controllers', () {
      final projectContext = ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: const Version(3, 44, 0),
      );

      final source = '''
        class MyWidget extends StatelessWidget {
          @override
          Widget build(BuildContext context) {
            _searchController.clear();
            _reasonController.dispose();
            final tabController = DefaultTabController(length: 2, child: Container());
            final scrollController = ScrollController();
            return Container();
          }
        }
      ''';

      final unit = parseString(content: source).unit;
      final fileContext = FileContext(
        filePath: 'lib/my_widget.dart',
        sourceCode: source,
        functions: const [],
        classes: const [],
        imports: const [],
        projectContext: projectContext,
        nativeAst: unit,
      );

      final findings = rule.analyzeFile(fileContext);
      expect(findings, isEmpty);
    });
  });

  group('MisplacedLayoutConstraintsRule', () {
    const config = RuleConfig(enabled: true, severity: Severity.error);
    final rule = MisplacedLayoutConstraintsRule(config: config);

    test('does not flag Expanded when nested inside Row, Column, or Flex', () {
      final projectContext = ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: const Version(3, 44, 0),
      );

      final source = '''
        Widget build(BuildContext context) {
          return Column(
            children: [
              Expanded(
                child: Container(),
              ),
            ],
          );
        }
      ''';

      final unit = parseString(content: source).unit;
      final fileContext = FileContext(
        filePath: 'lib/my_widget.dart',
        sourceCode: source,
        functions: const [],
        classes: const [],
        imports: const [],
        projectContext: projectContext,
        nativeAst: unit,
      );

      final findings = rule.analyzeFile(fileContext);
      expect(findings, isEmpty);
    });

    test('flags Expanded when nested inside a non-flexible container (e.g. Container, Card)', () {
      final projectContext = ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: const Version(3, 44, 0),
      );

      final source = '''
        Widget build(BuildContext context) {
          return Container(
            child: Expanded(
              child: Card(
                child: Spacer(),
              ),
            ),
          );
        }
      ''';

      final unit = parseString(content: source).unit;
      final fileContext = FileContext(
        filePath: 'lib/my_widget.dart',
        sourceCode: source,
        functions: const [],
        classes: const [],
        imports: const [],
        projectContext: projectContext,
        nativeAst: unit,
      );

      final findings = rule.analyzeFile(fileContext);
      expect(findings, hasLength(2));
      expect(findings[0].evidence['flexible_widget'], equals('Expanded'));
      expect(findings[0].evidence['actual_parent'], equals('Container'));
      expect(findings[1].evidence['flexible_widget'], equals('Spacer'));
      expect(findings[1].evidence['actual_parent'], equals('Card'));
    });
  });
}
