import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';
import 'package:vetro/analyzers/dart/rules/eigenvector_centrality_rule.dart';
import 'package:vetro/analyzers/dart/rules/halstead_complexity_rule.dart';
import 'package:vetro/analyzers/dart/rules/low_cohesion_rule.dart';
import 'package:vetro/analyzers/dart/rules/low_entropy_rule.dart';
import 'package:vetro/core/metrics/cohesion.dart';
import 'package:vetro/core/metrics/dependency_graph.dart';
import 'package:vetro/core/metrics/entropy.dart';
import 'package:vetro/core/metrics/halstead.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/finding.dart';

void main() {
  group('Halstead Complexity Rule & Metrics', () {
    test('halsteadMetrics computes expected stats', () {
      final source = '''
        void simple(int a, int b) {
          final sum = a + b;
          print(sum);
        }
      ''';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;
      final stats = halsteadMetrics(fn);

      expect(stats.totalOperators, greaterThan(0));
      expect(stats.totalOperands, greaterThan(0));
      expect(stats.distinctOperators, greaterThan(0));
      expect(stats.distinctOperands, greaterThan(0));
      expect(stats.volume, greaterThan(0.0));
      expect(stats.difficulty, greaterThan(0.0));
      expect(stats.effort, greaterThan(0.0));
    });

    test('HalsteadComplexityRule flags functions exceeding threshold', () {
      const config = RuleConfig(
        enabled: true,
        severity: Severity.warning,
        thresholds: {'max_effort': 10.0},
      );
      final rule = HalsteadComplexityRule(config: config);

      final source = '''
        void complexWorkflow(int a, int b) {
          final sum = a + b;
          final diff = a - b;
          final prod = a * b;
          print(sum + diff + prod);
        }
      ''';
      final unit = parseString(content: source).unit;
      final findings = rule.analyze(unit, 'test.dart', source);

      expect(findings, hasLength(1));
      expect(findings.first.ruleId, equals('halstead_complexity'));
      expect(findings.first.evidence['halstead_effort'], isNotNull);
    });

    test('HalsteadComplexityRule does not flag functions under threshold', () {
      const config = RuleConfig(
        enabled: true,
        severity: Severity.warning,
        thresholds: {'max_effort': 100000.0},
      );
      final rule = HalsteadComplexityRule(config: config);

      final source = '''
        void simple() {}
      ''';
      final unit = parseString(content: source).unit;
      final findings = rule.analyze(unit, 'test.dart', source);

      expect(findings, isEmpty);
    });
  });

  group('Low Entropy Rule & Metrics', () {
    test('shannonEntropy calculates variety of AST node types', () {
      final source = '''
        void foo(int x) {
          if (x > 0) {
            print(x);
          }
        }
      ''';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;
      final entropy = shannonEntropy(fn);

      expect(entropy, greaterThan(1.0));
    });

    test('LowEntropyRule flags functions with low entropy and enough nodes', () {
      // Create a highly repetitive function to keep entropy low.
      final source = '''
        void repetitive() {
          print(1);
          print(2);
          print(3);
          print(4);
          print(5);
          print(6);
          print(7);
          print(8);
          print(9);
          print(10);
        }
      ''';
      final unit = parseString(content: source).unit;

      // Ensure min_nodes is low enough to include the function,
      // and min_entropy is high enough to flag it.
      const config = RuleConfig(
        enabled: true,
        severity: Severity.warning,
        thresholds: {'min_entropy': 3.5, 'min_nodes': 10.0},
      );
      final rule = LowEntropyRule(config: config);
      final findings = rule.analyze(unit, 'test.dart', source);

      expect(findings, hasLength(1));
      expect(findings.first.ruleId, equals('low_entropy'));
    });

    test('LowEntropyRule does not flag functions with few nodes', () {
      final source = '''
        void short() {
          print(1);
        }
      ''';
      final unit = parseString(content: source).unit;
      const config = RuleConfig(
        enabled: true,
        severity: Severity.warning,
        thresholds: {'min_entropy': 5.0, 'min_nodes': 100.0},
      );
      final rule = LowEntropyRule(config: config);
      final findings = rule.analyze(unit, 'test.dart', source);

      expect(findings, isEmpty);
    });
  });

  group('Eigenvector Centrality Rule & Metrics', () {
    test('eigenvectorCentrality calculates PageRank-like import centrality', () {
      final graph = DependencyGraph();
      // Design a graph: A -> B, C -> B, B -> D.
      // B has high centrality as it is imported by A and C.
      graph.addEdge('A', 'B');
      graph.addEdge('C', 'B');
      graph.addEdge('B', 'D');

      final centrality = graph.eigenvectorCentrality();

      expect(centrality['B'], greaterThan(centrality['A']!));
      expect(centrality['B'], greaterThan(centrality['C']!));
      expect(centrality['D'], greaterThan(centrality['A']!));
    });

    test('EigenvectorCentralityRule flags central files in project', () async {
      // Mock files
      final sourceA = "import 'b.dart';";
      final sourceC = "import 'b.dart';";
      final sourceB = "import 'd.dart';";
      final sourceD = "void main() {}";

      final unitA = parseString(content: sourceA).unit;
      final unitB = parseString(content: sourceB).unit;
      final unitC = parseString(content: sourceC).unit;
      final unitD = parseString(content: sourceD).unit;

      final pathA = '/home/dimas/development/Vetro/lib/a.dart';
      final pathB = '/home/dimas/development/Vetro/lib/b.dart';
      final pathC = '/home/dimas/development/Vetro/lib/c.dart';
      final pathD = '/home/dimas/development/Vetro/lib/d.dart';

      final units = {
        pathA: unitA,
        pathB: unitB,
        pathC: unitC,
        pathD: unitD,
      };
      final sources = {
        pathA: sourceA,
        pathB: sourceB,
        pathC: sourceC,
        pathD: sourceD,
      };

      // Set low threshold to flag B
      const config = RuleConfig(
        enabled: true,
        thresholds: {'max_centrality': 0.5},
      );
      final rule = EigenvectorCentralityRule(config: config);
      final findings = await rule.analyzeProject(units, sources);

      final bFindings = findings.where((f) => f.filePath == pathB);
      expect(bFindings, isNotEmpty);
      expect(bFindings.first.ruleId, equals('eigenvector_centrality'));
    });
  });

  group('Low Cohesion Rule & Metrics', () {
    test('classCohesion computes average method identifier similarity', () {
      final source = '''
        class Cohesive {
          void first() {
            var shared = 1;
            print(shared);
          }
          void second() {
            var shared = 2;
            print(shared);
          }
          void third() {
            var shared = 3;
            print(shared);
          }
        }
      ''';
      final unit = parseString(content: source).unit;
      final cls = unit.declarations.first as ClassDeclaration;
      final cohesion = classCohesion(cls);

      expect(cohesion, greaterThan(0.5));
    });

    test('LowCohesionRule flags disjoint classes', () {
      final source = '''
        class Disjoint {
          void first() {
            var x = 1;
            print(x);
          }
          void second() {
            var y = 2;
            print(y);
          }
          void third() {
            var z = 3;
            print(z);
          }
        }
      ''';
      final unit = parseString(content: source).unit;

      const config = RuleConfig(
        enabled: true,
        severity: Severity.warning,
        thresholds: {'min_cohesion': 0.8},
      );
      final rule = LowCohesionRule(config: config);
      final findings = rule.analyze(unit, 'test.dart', source);

      expect(findings, hasLength(1));
      expect(findings.first.ruleId, equals('low_cohesion'));
    });

    test('LowCohesionRule does not flag cohesive classes', () {
      final source = '''
        class Cohesive {
          void first() {
            print(1);
          }
          void second() {
            print(2);
          }
        }
      ''';
      final unit = parseString(content: source).unit;

      const config = RuleConfig(
        enabled: true,
        severity: Severity.warning,
        thresholds: {'min_cohesion': 0.1},
      );
      final rule = LowCohesionRule(config: config);
      // Disjoint class with only 2 methods will skip LowCohesionRule because of members check >= 3
      final findings = rule.analyze(unit, 'test.dart', source);

      expect(findings, isEmpty);
    });
  });
}
