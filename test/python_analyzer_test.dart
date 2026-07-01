import 'package:test/test.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/py_node.dart';
import 'package:vetro/core/models/project_context.dart';
import 'package:vetro/analyzers/python/rules/py_semantic_duplication_rule.dart';
import 'package:vetro/analyzers/python/adapters/python_adapter.dart';

PyNode makeMockNode({
  required String type,
  int start = 0,
  int end = 100,
  int line = 1,
  Map<String, dynamic> extra = const {},
  List<PyNode> children = const [],
}) {
  final raw = <String, dynamic>{
    'type': type,
    'start': start,
    'end': end,
    ...extra,
  };
  return PyNode(
    type: type,
    raw: raw,
    children: children,
    start: start,
    end: end,
    line: line,
  );
}

void main() {
  group('Python Analyzer Rules - Unit Tests (Mock ASTs)', () {
    test('PySemanticDuplicationRule - detects similar function shapes', () async {
      final bodyA = makeMockNode(
        type: 'arguments',
        children: [
          makeMockNode(type: 'If'),
          makeMockNode(type: 'While'),
          makeMockNode(type: 'Return'),
          ...List.generate(30, (_) => makeMockNode(type: 'Name')),
        ],
      );

      final fnA = makeMockNode(
        type: 'FunctionDef',
        extra: {
          'name': 'functionA',
        },
        children: [bodyA],
      );

      final bodyB = makeMockNode(
        type: 'arguments',
        children: [
          makeMockNode(type: 'If'),
          makeMockNode(type: 'While'),
          makeMockNode(type: 'Return'),
          ...List.generate(30, (_) => makeMockNode(type: 'Name')),
        ],
      );

      final fnB = makeMockNode(
        type: 'FunctionDef',
        extra: {
          'name': 'functionB',
        },
        children: [bodyB],
      );

      final file1 = makeMockNode(type: 'Module', children: [fnA]);
      final file2 = makeMockNode(type: 'Module', children: [fnB]);

      final roots = {
        '/src/file1.py': file1,
        '/src/file2.py': file2,
      };

      final rule = PySemanticDuplicationRule(
        config: const RuleConfig(
          enabled: true,
          severity: Severity.warning,
          thresholds: {'similarity': 0.80},
        ),
      );

      final findings = await rule.analyzeProject(roots, {});
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, equals('semantic_duplication'));
      expect(findings.first.message, contains('functionA'));
      expect(findings.first.message, contains('functionB'));
    });

    test('PythonAdapter - only extracts top-level/direct class methods and ignores nested functions', () {
      // Nested local function inside functionDef: outer -> inner
      final innerFn = makeMockNode(
        type: 'FunctionDef',
        extra: {'name': 'inner_func'},
      );

      final outerFn = makeMockNode(
        type: 'FunctionDef',
        extra: {'name': 'outer_func'},
        children: [innerFn],
      );

      final root = makeMockNode(
        type: 'Module',
        children: [outerFn],
      );

      final adapter = const PythonAdapter(allFiles: {});
      final context = adapter.adapt(root, 'test.py', '', const ProjectContext.empty(projectPath: '.'));

      // outer_func should be extracted, inner_func should NOT be extracted.
      expect(context.functions, hasLength(1));
      expect(context.functions.first.name, equals('outer_func'));
    });
  });
}
