import 'package:test/test.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/ts_node.dart';
import 'package:vetro/analyzers/typescript/rules/ts_cyclomatic_complexity_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_cognitive_complexity_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_low_entropy_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_intent_gap_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_low_cohesion_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_tight_coupling_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_circular_dependency_rule.dart';
import 'package:vetro/analyzers/typescript/rules/ts_semantic_duplication_rule.dart';

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

void main() {
  group('TypeScript Analyzer Rules - Unit Tests (Mock ASTs)', () {
    test('TsCyclomaticComplexityRule - flags complex functions', () {
      const config = RuleConfig(
        enabled: true,
        severity: Severity.warning,
        thresholds: {'max_complexity': 2.0},
      );
      final rule = TsCyclomaticComplexityRule(config: config);

      // Function with an IfStatement and a WhileStatement -> CC = 3
      final body = makeMockNode(
        type: 'BlockStatement',
        children: [
          makeMockNode(type: 'IfStatement'),
          makeMockNode(type: 'WhileStatement'),
        ],
      );

      final fn = makeMockNode(
        type: 'FunctionDeclaration',
        extra: {
          'id': {'name': 'myComplexFunction'}
        },
        children: [body],
      );

      final findings = rule.analyze(fn, 'test.ts', '');
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, equals('cyclomatic_complexity'));
      expect(findings.first.message, contains('myComplexFunction'));
      expect(findings.first.evidence['cyclomatic_complexity'], equals('3'));
    });

    test('TsCognitiveComplexityRule - counts nesting level correctly', () {
      const config = RuleConfig(
        enabled: true,
        severity: Severity.warning,
        thresholds: {'max_cognitive_complexity': 2.0},
      );
      final rule = TsCognitiveComplexityRule(config: config);

      // If statement nested inside another If statement
      // Outer if: complexity +1, nesting level +1
      // Inner if: complexity +(1 + 1) = +2
      // Total cognitive complexity = 3
      final innerIf = makeMockNode(type: 'IfStatement');
      final outerIf = makeMockNode(
        type: 'IfStatement',
        children: [innerIf],
        extra: {
          'consequent': {'start': 10, 'end': 90}
        },
      );
      // Give innerIf a start position matching consequent to traverse properly
      final positionedInnerIf = makeMockNode(
        type: 'IfStatement',
        start: 20,
        end: 80,
      );
      final outerIfWithChild = makeMockNode(
        type: 'IfStatement',
        children: [positionedInnerIf],
        extra: {
          'consequent': {'start': 20, 'end': 80}
        },
      );

      final body = makeMockNode(
        type: 'BlockStatement',
        children: [outerIfWithChild],
      );

      final fn = makeMockNode(
        type: 'FunctionDeclaration',
        extra: {
          'id': {'name': 'nestedIfFunction'}
        },
        children: [body],
      );

      final findings = rule.analyze(fn, 'test.ts', '');
      expect(findings, hasLength(1));
      expect(findings.first.evidence['cognitive_complexity'], equals('3'));
    });

    test('TsLowEntropyRule - flags repetitive / low-entropy structures', () {
      const config = RuleConfig(
        enabled: true,
        severity: Severity.warning,
        thresholds: {
          'min_entropy': 2.0,
          'min_nodes': 10.0, // Low threshold for testing
          'min_identifier_entropy': 2.5
        },
      );
      final rule = TsLowEntropyRule(config: config);

      // Create a function body with 15 nodes, all of the same type ('Identifier')
      // and sharing the same name ('x')
      final repeatedIdentifiers = List.generate(
        15,
        (_) => makeMockNode(
          type: 'Identifier',
          extra: {'name': 'x'},
        ),
      );

      final body = makeMockNode(
        type: 'BlockStatement',
        children: repeatedIdentifiers,
      );

      final fn = makeMockNode(
        type: 'FunctionDeclaration',
        extra: {
          'id': {'name': 'repetitiveFn'}
        },
        children: [body],
      );

      final findings = rule.analyze(fn, 'test.ts', '');
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, equals('low_entropy'));
    });

    test('TsIntentGapRule - flags complex functions lacking explanations', () {
      const config = RuleConfig(
        enabled: true,
        severity: Severity.info,
        thresholds: {'min_complexity': 2.0},
      );
      final rule = TsIntentGapRule(config: config);

      // Function with CC = 3 (Block with 2 Ifs)
      final body = makeMockNode(
        type: 'BlockStatement',
        children: [
          makeMockNode(type: 'IfStatement'),
          makeMockNode(type: 'IfStatement'),
        ],
      );

      final fn = makeMockNode(
        type: 'FunctionDeclaration',
        start: 10,
        end: 100,
        extra: {
          'id': {'name': 'complexNoComments'}
        },
        children: [body],
      );

      // Root File node without comments
      final root = makeMockNode(
        type: 'File',
        children: [fn],
        extra: {
          'comments': []
        },
      );

      final findings = rule.analyze(root, 'test.ts', '');
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, equals('intent_gap'));
    });

    test('TsLowCohesionRule - flags class with disjoint method vocabularies', () {
      const config = RuleConfig(
        enabled: true,
        severity: Severity.warning,
        thresholds: {'min_cohesion': 0.20, 'min_methods': 3.0},
      );
      final rule = TsLowCohesionRule(config: config);

      // Methods using completely different variable names
      final m1 = makeMockNode(
        type: 'ClassMethod',
        extra: {
          'kind': 'method',
          'key': {'name': 'methodOne'}
        },
        children: [
          makeMockNode(type: 'Identifier', extra: {'name': 'apple'}),
        ],
      );

      final m2 = makeMockNode(
        type: 'ClassMethod',
        extra: {
          'kind': 'method',
          'key': {'name': 'methodTwo'}
        },
        children: [
          makeMockNode(type: 'Identifier', extra: {'name': 'banana'}),
        ],
      );

      final m3 = makeMockNode(
        type: 'ClassMethod',
        extra: {
          'kind': 'method',
          'key': {'name': 'methodThree'}
        },
        children: [
          makeMockNode(type: 'Identifier', extra: {'name': 'cherry'}),
        ],
      );

      final classBody = makeMockNode(
        type: 'ClassBody',
        children: [m1, m2, m3],
      );

      final classNode = makeMockNode(
        type: 'ClassDeclaration',
        extra: {
          'id': {'name': 'DisjointClass'}
        },
        children: [classBody],
      );

      final root = makeMockNode(
        type: 'File',
        children: [classNode],
      );

      final findings = rule.analyze(root, 'test.ts', '');
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, equals('low_cohesion'));
      expect(findings.first.message, contains('DisjointClass'));
    });

    test('TsTightCouplingRule & TsCircularDependencyRule - detects cross-file rules', () async {
      // Setup file structure in memory: A imports B, B imports C, C imports A
      final fileA = makeMockNode(
        type: 'File',
        children: [
          makeMockNode(
            type: 'ImportDeclaration',
            extra: {
              'source': {'value': './fileB'}
            },
          )
        ],
      );

      final fileB = makeMockNode(
        type: 'File',
        children: [
          makeMockNode(
            type: 'ImportDeclaration',
            extra: {
              'source': {'value': './fileC'}
            },
          )
        ],
      );

      final fileC = makeMockNode(
        type: 'File',
        children: [
          makeMockNode(
            type: 'ImportDeclaration',
            extra: {
              'source': {'value': './fileA'}
            },
          )
        ],
      );

      final projectRoots = {
        '/src/fileA.ts': fileA,
        '/src/fileB.ts': fileB,
        '/src/fileC.ts': fileC,
      };

      final couplingRule = TsTightCouplingRule(
        config: const RuleConfig(
          enabled: true,
          severity: Severity.warning,
          thresholds: {'max_coupling': 0.20},
        ),
      );

      final circularRule = TsCircularDependencyRule(
        config: const RuleConfig(
          enabled: true,
          severity: Severity.warning,
        ),
      );

      final couplingFindings = await couplingRule.analyzeProject(projectRoots, {});
      expect(couplingFindings, isNotEmpty);
      expect(couplingFindings.first.ruleId, equals('tight_coupling'));

      final circularFindings = await circularRule.analyzeProject(projectRoots, {});
      expect(circularFindings, hasLength(1));
      expect(circularFindings.first.ruleId, equals('circular_dependency'));
      expect(circularFindings.first.message, contains('fileA.ts -> fileB.ts -> fileC.ts -> fileA.ts'));
    });

    test('TsSemanticDuplicationRule - detects similar function shapes', () async {
      final bodyA = makeMockNode(
        type: 'BlockStatement',
        children: [
          makeMockNode(type: 'IfStatement'),
          makeMockNode(type: 'WhileStatement'),
          makeMockNode(type: 'ReturnStatement'),
          ...List.generate(30, (_) => makeMockNode(type: 'Identifier')),
        ],
      );

      final fnA = makeMockNode(
        type: 'FunctionDeclaration',
        extra: {
          'id': {'name': 'functionA'}
        },
        children: [bodyA],
      );

      final bodyB = makeMockNode(
        type: 'BlockStatement',
        children: [
          makeMockNode(type: 'IfStatement'),
          makeMockNode(type: 'WhileStatement'),
          makeMockNode(type: 'ReturnStatement'),
          ...List.generate(30, (_) => makeMockNode(type: 'Identifier')),
        ],
      );

      final fnB = makeMockNode(
        type: 'FunctionDeclaration',
        extra: {
          'id': {'name': 'functionB'}
        },
        children: [bodyB],
      );

      final file1 = makeMockNode(type: 'File', children: [fnA]);
      final file2 = makeMockNode(type: 'File', children: [fnB]);

      final roots = {
        '/src/file1.ts': file1,
        '/src/file2.ts': file2,
      };

      final rule = TsSemanticDuplicationRule(
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
  });
}
