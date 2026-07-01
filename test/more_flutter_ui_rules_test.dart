import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:vetro/analyzers/dart/rules/unreleased_controllers_rule.dart';
import 'package:vetro/analyzers/dart/rules/hardcoded_ui_tokens_rule.dart';
import 'package:vetro/analyzers/dart/rules/set_state_in_complex_builds_rule.dart';
import 'package:vetro/analyzers/dart/rules/missing_const_constructors_rule.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/project_context.dart';

void main() {
  group('UnreleasedControllersRule', () {
    const config = RuleConfig(enabled: true, severity: Severity.error);
    final rule = UnreleasedControllersRule(config: config);

    test('flags controllers declared in State class when dispose() is missing', () {
      final projectContext = const ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: Version(3, 44, 0),
      );

      final source = '''
        class MyWidget extends StatefulWidget {
          @override
          _MyWidgetState createState() => _MyWidgetState();
        }

        class _MyWidgetState extends State<MyWidget> {
          final _textController = TextEditingController();
          final _scrollController = ScrollController();

          @override
          Widget build(BuildContext context) {
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
      expect(findings[0].evidence['controller'], equals('_textController'));
      expect(findings[1].evidence['controller'], equals('_scrollController'));
    });

    test('flags only the controllers that are NOT disposed inside dispose()', () {
      final projectContext = const ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: Version(3, 44, 0),
      );

      final source = '''
        class _MyWidgetState extends State<MyWidget> {
          final _textController = TextEditingController();
          final _scrollController = ScrollController();

          @override
          void dispose() {
            _textController.dispose();
            super.dispose();
          }

          @override
          Widget build(BuildContext context) {
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
      expect(findings.first.evidence['controller'], equals('_scrollController'));
    });

    test('does not flag controllers when all are properly disposed', () {
      final projectContext = const ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: Version(3, 44, 0),
      );

      final source = '''
        class _MyWidgetState extends State<MyWidget> {
          final _textController = TextEditingController();
          final _scrollController = ScrollController();

          @override
          void dispose() {
            _textController.dispose();
            _scrollController.dispose();
            super.dispose();
          }

          @override
          Widget build(BuildContext context) {
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

  group('HardcodedUiTokensRule', () {
    const config = RuleConfig(enabled: true, severity: Severity.warning);
    final rule = HardcodedUiTokensRule(config: config);

    test('flags raw Color and TextStyle instantiations inline in build method', () {
      final projectContext = const ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: Version(3, 44, 0),
      );

      final source = '''
        class MyWidget extends StatelessWidget {
          @override
          Widget build(BuildContext context) {
            final color = Color(0xFF123456);
            return Text(
              'Hello',
              style: TextStyle(fontSize: 16.0),
            );
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
    });

    test('does not flag Color or TextStyle declared outside build method', () {
      final projectContext = const ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: Version(3, 44, 0),
      );

      final source = '''
        const myColor = Color(0xFF123456);
        const myStyle = TextStyle(fontSize: 16.0);

        class MyWidget extends StatelessWidget {
          @override
          Widget build(BuildContext context) {
            return Text('Hello', style: myStyle);
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

  group('SetStateInComplexBuildsRule', () {
    const config = RuleConfig(
      enabled: true,
      severity: Severity.warning,
      thresholds: {'max_build_complexity': 5.0}, // Keep it low for unit tests
    );
    final rule = SetStateInComplexBuildsRule(config: config);

    test('flags setState when build method complexity exceeds threshold', () {
      final projectContext = const ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: Version(3, 44, 0),
      );

      // Complex build: 6 branches (1 + 5 decisions: if, switch case, if, ||, ternaries)
      final source = '''
        class _MyWidgetState extends State<MyWidget> {
          int _counter = 0;

          void _increment() {
            setState(() {
              _counter++;
            });
          }

          @override
          Widget build(BuildContext context) {
            if (true) {}
            if (false) {}
            final check = true || false;
            final ternary = check ? 1 : 2;
            switch (ternary) {
              case 1:
                return Container();
              default:
                return SizedBox();
            }
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
      expect(findings.first.evidence['build_complexity'], equals('6'));
    });

    test('does not flag setState when build method is simple', () {
      final projectContext = const ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: Version(3, 44, 0),
      );

      final source = '''
        class _MyWidgetState extends State<MyWidget> {
          int _counter = 0;

          void _increment() {
            setState(() {
              _counter++;
            });
          }

          @override
          Widget build(BuildContext context) {
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

  group('MissingConstConstructorsRule', () {
    const config = RuleConfig(enabled: true, severity: Severity.warning);
    final rule = MissingConstConstructorsRule(config: config);

    test('flags static widgets created dynamically', () {
      final projectContext = const ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: Version(3, 44, 0),
      );

      final source = '''
        class MyWidget extends StatelessWidget {
          @override
          Widget build(BuildContext context) {
            return Column(
              children: [
                SizedBox(width: 10),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Hello'),
                ),
              ],
            );
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
      // Flags: SizedBox, Padding, EdgeInsets.all, Text
      expect(findings, hasLength(4));
    });

    test('does not flag dynamic widgets or widgets inside a const parent', () {
      final projectContext = const ProjectContext(
        projectPath: '.',
        isFlutterProject: true,
        flutterVersion: Version(3, 44, 0),
      );

      final source = '''
        class MyWidget extends StatelessWidget {
          final String title;
          MyWidget({required this.title});

          @override
          Widget build(BuildContext context) {
            final dynamicWidget = SizedBox(width: MediaQuery.of(context).size.width);
            final dynamicText = Text(title);
            
            return const Column(
              children: [
                SizedBox(width: 10),
                Text('Constant'),
              ],
            );
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
}
