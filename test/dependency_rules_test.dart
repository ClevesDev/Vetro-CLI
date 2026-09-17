import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:vetro/analyzers/dart/rules/circular_dependency_rule.dart';
import 'package:vetro/analyzers/dart/rules/tight_coupling_rule.dart';
import 'package:vetro/core/models/config.dart';

void main() {
  group('Circular Dependency Rule', () {
    test('detects cycles between files', () async {
      const sourceA = "import 'b.dart';";
      const sourceB = "import 'c.dart';";
      const sourceC = "import 'a.dart';";

      final unitA = parseString(content: sourceA).unit;
      final unitB = parseString(content: sourceB).unit;
      final unitC = parseString(content: sourceC).unit;

      final root = Directory.current.path;
      final pathA = p.join(root, 'lib', 'a.dart');
      final pathB = p.join(root, 'lib', 'b.dart');
      final pathC = p.join(root, 'lib', 'c.dart');

      final units = {pathA: unitA, pathB: unitB, pathC: unitC};
      final sources = {pathA: sourceA, pathB: sourceB, pathC: sourceC};

      const rule = CircularDependencyRule(config: RuleConfig(enabled: true));
      final findings = await rule.analyzeProject(units, sources);

      expect(findings, isNotEmpty);
      expect(findings.first.ruleId, equals('circular_dependency'));
      expect(
        findings.first.message,
        contains('lib/a.dart -> lib/b.dart -> lib/c.dart -> lib/a.dart'),
      );
    });
  });

  group('Tight Coupling Rule', () {
    test('flags files with coupling ratio above threshold', () async {
      // Create a star topology where center.dart imports everything, and everything imports center.dart.
      const sourceCenter = "import 'a.dart'; import 'b.dart'; import 'c.dart';";
      const sourceA = "import 'center.dart';";
      const sourceB = "import 'center.dart';";
      const sourceC = "import 'center.dart';";

      final unitCenter = parseString(content: sourceCenter).unit;
      final unitA = parseString(content: sourceA).unit;
      final unitB = parseString(content: sourceB).unit;
      final unitC = parseString(content: sourceC).unit;

      final root = Directory.current.path;
      final pathCenter = p.join(root, 'lib', 'center.dart');
      final pathA = p.join(root, 'lib', 'a.dart');
      final pathB = p.join(root, 'lib', 'b.dart');
      final pathC = p.join(root, 'lib', 'c.dart');

      final units = {
        pathCenter: unitCenter,
        pathA: unitA,
        pathB: unitB,
        pathC: unitC,
      };
      final sources = {
        pathCenter: sourceCenter,
        pathA: sourceA,
        pathB: sourceB,
        pathC: sourceC,
      };

      // totalNodes = 4. coupling(center) = (fanIn: 3 + fanOut: 3) / 4 = 1.5. Threshold: 0.50.
      const rule = TightCouplingRule(
        config: RuleConfig(enabled: true, thresholds: {'max_coupling': 0.5}),
      );
      final findings = await rule.analyzeProject(units, sources);

      final centerFindings = findings.where((f) => f.filePath == pathCenter);
      expect(centerFindings, isNotEmpty);
      expect(centerFindings.first.ruleId, equals('tight_coupling'));
      expect(centerFindings.first.message, contains('tight coupling: 150.0%'));
    });

    test('does not flag leaf nodes with fan-out < min_fan_out despite high fan-in', () async {
      // Leaf tokens file imported by everyone, but importing nothing itself (fan-out: 0)
      const sourceTokens = '';
      const sourceA = "import 'tokens.dart';";
      const sourceB = "import 'tokens.dart';";
      const sourceC = "import 'tokens.dart';";

      final unitTokens = parseString(content: sourceTokens).unit;
      final unitA = parseString(content: sourceA).unit;
      final unitB = parseString(content: sourceB).unit;
      final unitC = parseString(content: sourceC).unit;

      final root = Directory.current.path;
      final pathTokens = p.join(root, 'lib', 'tokens.dart');
      final pathA = p.join(root, 'lib', 'a.dart');
      final pathB = p.join(root, 'lib', 'b.dart');
      final pathC = p.join(root, 'lib', 'c.dart');

      final units = {
        pathTokens: unitTokens,
        pathA: unitA,
        pathB: unitB,
        pathC: unitC,
      };
      final sources = {
        pathTokens: sourceTokens,
        pathA: sourceA,
        pathB: sourceB,
        pathC: sourceC,
      };

      const rule = TightCouplingRule(
        config: RuleConfig(enabled: true, thresholds: {'max_coupling': 0.1}),
      );
      final findings = await rule.analyzeProject(units, sources);

      final tokenFindings = findings.where((f) => f.filePath == pathTokens);
      expect(tokenFindings, isEmpty);
    });
  });
}
