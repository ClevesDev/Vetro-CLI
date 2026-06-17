import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:vetro/analyzers/dart/adapters/dart_adapter.dart';
import 'package:vetro/analyzers/python/adapters/python_adapter.dart';
import 'package:vetro/analyzers/typescript/adapters/typescript_adapter.dart';
import 'package:vetro/core/models/py_node.dart';
import 'package:vetro/core/models/ts_node.dart';

TsNode makeMockNode({
  required String type,
  int start = 0,
  int end = 100,
  int line = 1,
  Map<String, dynamic> extra = const {},
  List<TsNode> children = const [],
}) {
  final raw = <String, dynamic>{
    'type': type,
    'start': start,
    'end': end,
    ...extra,
  };
  return TsNode(
    type: type,
    raw: raw,
    children: children,
    start: start,
    end: end,
    line: line,
  );
}

PyNode makeMockPyNode({
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
  group('Language Parity Tests', () {
    test('Dart, TypeScript, and Python adapter complexity parity', () {
      // 1. Equivalent complex function in Dart
      const dartSource = '''
        void myFunction(int x) {
          if (x > 0) {
            while (x < 10) {
              x++;
            }
          }
        }
      ''';
      
      final dartResult = parseString(content: dartSource);
      const dartAdapter = DartAdapter();
      final dartContext = dartAdapter.adapt(dartResult.unit, 'test.dart', dartSource);
      
      expect(dartContext.functions, hasLength(1));
      final dartFn = dartContext.functions.first;
      expect(dartFn.cyclomaticComplexity, equals(3));
      expect(dartFn.cognitiveComplexity, equals(3)); // 1 (outer if) + 2 (inner nested while) = 3
      
      // 2. TypeScript mock version of the same structure
      // We construct a nested structure: IfStatement containing a WhileStatement
      final tsInner = makeMockNode(
        type: 'WhileStatement',
        start: 30,
        end: 70,
      );
      final tsOuterIf = makeMockNode(
        type: 'IfStatement',
        start: 10,
        end: 90,
        children: [tsInner],
        extra: {
          'consequent': const {'start': 30, 'end': 70}
        },
      );
      final tsBody = makeMockNode(
        type: 'BlockStatement',
        children: [tsOuterIf],
      );
      final tsFn = makeMockNode(
        type: 'FunctionDeclaration',
        extra: {
          'id': const {'name': 'myFunction'}
        },
        children: [tsBody],
      );
      final tsRoot = makeMockNode(
        type: 'File',
        children: [tsFn],
      );

      const tsAdapter = TsAdapter(allFiles: {});
      final tsContext = tsAdapter.adapt(tsRoot, 'test.ts', '');
      
      expect(tsContext.functions, hasLength(1));
      final tsFnCtx = tsContext.functions.first;
      
      expect(tsFnCtx.cyclomaticComplexity, equals(dartFn.cyclomaticComplexity));
      expect(tsFnCtx.cognitiveComplexity, equals(dartFn.cognitiveComplexity));

      // 3. Python mock version of the same structure
      // We construct a nested structure: If containing a While
      final pyInner = makeMockPyNode(
        type: 'While',
        start: 30,
        end: 70,
      );
      final pyOuterIf = makeMockPyNode(
        type: 'If',
        start: 10,
        end: 90,
        children: [pyInner],
      );
      final pyFn = makeMockPyNode(
        type: 'FunctionDef',
        extra: {
          'name': 'myFunction',
        },
        children: [pyOuterIf],
      );
      final pyRoot = makeMockPyNode(
        type: 'Module',
        children: [pyFn],
      );

      const pyAdapter = PythonAdapter(allFiles: {});
      final pyContext = pyAdapter.adapt(pyRoot, 'test.py', '');

      expect(pyContext.functions, hasLength(1));
      final pyFnCtx = pyContext.functions.first;

      expect(pyFnCtx.cyclomaticComplexity, equals(dartFn.cyclomaticComplexity));
      expect(pyFnCtx.cognitiveComplexity, equals(dartFn.cognitiveComplexity));
    });
  });
}
