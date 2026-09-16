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
      final sourceA = "import 'b.dart';";
      final sourceB = "import 'c.dart';";
      final sourceC = "import 'a.dart';";

      final unitA = parseString(content: sourceA).unit;
      final unitB = parseString(content: sourceB).unit;
      final unitC = parseString(content: sourceC).unit;

      final root = Directory.current.path;
      final pathA = p.join(root, 'lib', 'a.dart');
      final pathB = p.join(root, 'lib', 'b.dart');
      final pathC = p.join(root, 'lib', 'c.dart');

      final units = {
        pathA: unitA,
        pathB: unitB,
        pathC: unitC,
      };
      final sources = {
        pathA: sourceA,
        pathB: sourceB,
        pathC: sourceC,
      };

      const rule = CircularDependencyRule(config: RuleConfig(enabled: true));
      final findings = await rule.analyzeProject(units, sources);

      expect(findings, isNotEmpty);
      expect(findings.first.ruleId, equals('circular_dependency'));
      expect(findings.first.message, contains('lib/a.dart -> lib/b.dart -> lib/c.dart -> lib/a.dart'));
    });
  });

  group('Tight Coupling Rule', () {
    test('flags files with coupling ratio above threshold', () async {
      // Create a star topology where center.dart imports everything, and everything imports center.dart.
      final sourceCenter = "import 'a.dart'; import 'b.dart'; import 'c.dart';";
      final sourceA = "import 'center.dart';";
      final sourceB = "import 'center.dart';";
      final sourceC = "import 'center.dart';";

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
      const rule = TightCouplingRule(config: RuleConfig(
        enabled: true,
        thresholds: {'max_coupling': 0.5},
      ));
      final findings = await rule.analyzeProject(units, sources);

      final centerFindings = findings.where((f) => f.filePath == pathCenter);
      expect(centerFindings, isNotEmpty);
      expect(centerFindings.first.ruleId, equals('tight_coupling'));
      expect(centerFindings.first.message, contains('tight coupling: 150.0%'));
    });
  });
}
