import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:vetro/analyzers/dart/rules/boundary_violation_rule.dart';
import 'package:vetro/core/models/config.dart';

void main() {
  group('Boundary Violation Rule', () {
    test('allows clean inward flows (outer layers importing inner layers)', () async {
      final sourceDomain = "class DomainClass {}";
      final sourceApp = "import 'domain/domain.dart'; class AppClass {}";
      final sourceInfra = "import '../domain/domain.dart'; class InfraClass {}";
      final sourcePres = "import '../../domain/domain.dart'; import '../application/app.dart'; class PresClass {}";

      final pathDomain = '/home/dimas/development/Vetro/lib/domain/domain.dart';
      final pathApp = '/home/dimas/development/Vetro/lib/application/app.dart';
      final pathInfra = '/home/dimas/development/Vetro/lib/infrastructure/infra.dart';
      final pathPres = '/home/dimas/development/Vetro/lib/presentation/pres.dart';

      final units = {
        pathDomain: parseString(content: sourceDomain).unit,
        pathApp: parseString(content: sourceApp).unit,
        pathInfra: parseString(content: sourceInfra).unit,
        pathPres: parseString(content: sourcePres).unit,
      };

      final sources = {
        pathDomain: sourceDomain,
        pathApp: sourceApp,
        pathInfra: sourceInfra,
        pathPres: sourcePres,
      };

      const rule = BoundaryViolationRule(
        config: RuleConfig(
          enabled: true,
          options: {
            'layers': ['domain', 'application', 'infrastructure', 'presentation']
          },
        ),
      );

      final findings = await rule.analyzeProject(units, sources);
      expect(findings, isEmpty);
    });

    test('flags invalid outward flows (inner layers importing outer layers)', () async {
      final sourceDomain = "import '../presentation/pres.dart'; class DomainClass {}";
      final sourcePres = "class PresClass {}";

      final pathDomain = '/home/dimas/development/Vetro/lib/domain/domain.dart';
      final pathPres = '/home/dimas/development/Vetro/lib/presentation/pres.dart';

      final units = {
        pathDomain: parseString(content: sourceDomain).unit,
        pathPres: parseString(content: sourcePres).unit,
      };

      final sources = {
        pathDomain: sourceDomain,
        pathPres: sourcePres,
      };

      const rule = BoundaryViolationRule(
        config: RuleConfig(
          enabled: true,
          options: {
            'layers': ['domain', 'application', 'infrastructure', 'presentation']
          },
        ),
      );

      final findings = await rule.analyzeProject(units, sources);
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, equals('boundary_violation'));
      expect(findings.first.filePath, equals(pathDomain));
      expect(findings.first.line, equals(1));
      expect(findings.first.message, contains('Boundary violation: Layer "domain" (innermost) cannot import outer layer "presentation"'));
    });

    test('respects custom layers configuration', () async {
      final sourceCore = "import '../ui/ui.dart'; class CoreClass {}";
      final sourceUi = "class UiClass {}";

      final pathCore = '/home/dimas/development/Vetro/lib/core/core.dart';
      final pathUi = '/home/dimas/development/Vetro/lib/ui/ui.dart';

      final units = {
        pathCore: parseString(content: sourceCore).unit,
        pathUi: parseString(content: sourceUi).unit,
      };

      final sources = {
        pathCore: sourceCore,
        pathUi: sourceUi,
      };

      const rule = BoundaryViolationRule(
        config: RuleConfig(
          enabled: true,
          options: {
            'layers': ['core', 'infra', 'ui']
          },
        ),
      );

      final findings = await rule.analyzeProject(units, sources);
      expect(findings, hasLength(1));
      expect(findings.first.message, contains('Boundary violation: Layer "core" (innermost) cannot import outer layer "ui"'));
    });

    test('ignores unlayered helper files and folders', () async {
      final sourceDomain = "import '../shared/utils.dart'; class DomainClass {}";
      final sourceShared = "import '../presentation/pres.dart'; class SharedUtils {}";
      final sourcePres = "class PresClass {}";

      final pathDomain = '/home/dimas/development/Vetro/lib/domain/domain.dart';
      final pathShared = '/home/dimas/development/Vetro/lib/shared/utils.dart';
      final pathPres = '/home/dimas/development/Vetro/lib/presentation/pres.dart';

      final units = {
        pathDomain: parseString(content: sourceDomain).unit,
        pathShared: parseString(content: sourceShared).unit,
        pathPres: parseString(content: sourcePres).unit,
      };

      final sources = {
        pathDomain: sourceDomain,
        pathShared: sourceShared,
        pathPres: sourcePres,
      };

      const rule = BoundaryViolationRule(
        config: RuleConfig(
          enabled: true,
          options: {
            'layers': ['domain', 'application', 'infrastructure', 'presentation']
          },
        ),
      );

      final findings = await rule.analyzeProject(units, sources);
      // Even though shared imports presentation, shared is not in configured layers list,
      // so it is skipped.
      expect(findings, isEmpty);
    });

    test('resolves package imports correctly', () async {
      final sourceDomain = "import 'package:vetro/presentation/pres.dart'; class DomainClass {}";
      final sourcePres = "class PresClass {}";

      final pathDomain = '/home/dimas/development/Vetro/lib/domain/domain.dart';
      final pathPres = '/home/dimas/development/Vetro/lib/presentation/pres.dart';

      final units = {
        pathDomain: parseString(content: sourceDomain).unit,
        pathPres: parseString(content: sourcePres).unit,
      };

      final sources = {
        pathDomain: sourceDomain,
        pathPres: sourcePres,
      };

      const rule = BoundaryViolationRule(
        config: RuleConfig(
          enabled: true,
          options: {
            'layers': ['domain', 'presentation']
          },
        ),
      );

      final findings = await rule.analyzeProject(units, sources);
      expect(findings, hasLength(1));
      expect(findings.first.message, contains('Boundary violation: Layer "domain" (innermost) cannot import outer layer "presentation"'));
    });
  });
}
