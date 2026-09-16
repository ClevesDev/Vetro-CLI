import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/report/prompt_reporter.dart';

void main() {
  group('PromptReporter', () {
    const reporter = PromptReporter();
    late Directory tempDir;
    late File tempFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('vetro_prompt_test');
      tempFile = File(p.join(tempDir.path, 'source.dart'));
      tempFile.writeAsStringSync('''
void example() {
  print('Line 1');
  print('Line 2');
  print('Line 3');
  print('Line 4');
  print('Line 5');
  print('Line 6'); // This is line 7
  print('Line 7');
  print('Line 8');
  print('Line 9');
  print('Line 10');
}
''');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('formats clean report correctly', () {
      final report = ProjectReport(
        projectPath: tempDir.path,
        fileReports: [],
        totalAnalysisTimeMs: 10,
        analyzedAt: DateTime(2026, 6, 17, 12, 0, 0),
      );

      final output = reporter.format(report);
      expect(output, contains('🤖 Vetro AI Remedy Prompts'));
      expect(
        output,
        contains(
          'No se encontraron hallazgos de deuda. ¡El código está impecable!',
        ),
      );
    });

    test('generates remedy prompt with snippet and instructions', () {
      final finding = Finding(
        ruleId: 'cognitive_complexity',
        ruleName: 'Cognitive Complexity',
        severity: Severity.warning,
        filePath: tempFile.path,
        line: 7, // corresponds to Line 6 comment in the setUp file
        message: 'Function has cognitive complexity of 12 (threshold is 10)',
        evidence: {'complexity': '12', 'threshold': '10'},
      );

      final fileReport = FileReport(
        filePath: tempFile.path,
        findings: [finding],
        lineCount: 12,
        analysisTimeMs: 5,
      );

      final report = ProjectReport(
        projectPath: tempDir.path,
        fileReports: [fileReport],
        totalAnalysisTimeMs: 15,
        analyzedAt: DateTime(2026, 6, 17, 12, 0, 0),
      );

      final output = reporter.format(report);

      expect(output, contains('🤖 Vetro AI Remedy Prompts'));
      expect(output, contains('Remedio #1: Cognitive Complexity'));
      expect(output, contains('**Ubicación:** `source.dart:7`'));
      expect(output, contains('**Severidad:** `WARNING`'));
      expect(
        output,
        contains('Function has cognitive complexity of 12 (threshold is 10)'),
      );

      // Code Context snippet checking
      expect(output, contains('### Código de Contexto:'));
      expect(output, contains('👉 7:   print(\'Line 6\'); // This is line 7'));
      expect(output, contains('   2:   print(\'Line 1\');')); // context lines

      // Evidence checking
      expect(output, contains('### Evidencia Métrica:'));
      expect(output, contains('- **complexity**: `12`'));
      expect(output, contains('- **threshold**: `10`'));

      // Prompt / Instructions checking
      expect(
        output,
        contains(
          '### 📋 Prompt / Instrucciones de Refactorización para la IA:',
        ),
      );
      expect(
        output,
        contains(
          'Actúa como un ingeniero de software experto en refactorización de código limpio.',
        ),
      );
      expect(
        output,
        contains(
          'Reduce el anidamiento de control. Utiliza guardias y retornos tempranos (early returns).',
        ),
      );
    });

    test('handles missing file gracefully without failing', () {
      final missingFilePath = p.join(tempDir.path, 'does_not_exist.dart');
      final finding = Finding(
        ruleId: 'intent_gap',
        ruleName: 'Intent Gap',
        severity: Severity.info,
        filePath: missingFilePath,
        line: 15,
        message: 'No intent comments in complex function',
      );

      final fileReport = FileReport(
        filePath: missingFilePath,
        findings: [finding],
        lineCount: 30,
        analysisTimeMs: 5,
      );

      final report = ProjectReport(
        projectPath: tempDir.path,
        fileReports: [fileReport],
        totalAnalysisTimeMs: 15,
        analyzedAt: DateTime(2026, 6, 17, 12, 0, 0),
      );

      final output = reporter.format(report);

      expect(output, contains('Remedio #1: Intent Gap'));
      expect(output, contains('**Ubicación:** `does_not_exist.dart:15`'));
      // No snippet should be present because the file doesn't exist
      expect(output, isNot(contains('### Código de Contexto:')));
      expect(
        output,
        contains(
          'Añade un comentario de docstring descriptivo que responda a: ¿por qué se tomó esta decisión de diseño',
        ),
      );
    });

    test('sorts remedies in topological order of architectural impact', () {
      final fileReport = FileReport(
        filePath: tempFile.path,
        findings: [
          Finding(
            ruleId: 'cognitive_complexity',
            ruleName: 'Cognitive Complexity',
            severity: Severity.warning,
            filePath: tempFile.path,
            line: 5,
            message: 'High cognitive complexity',
          ),
          Finding(
            ruleId: 'boundary_violation',
            ruleName: 'Boundary Violation',
            severity: Severity.error,
            filePath: tempFile.path,
            line: 2,
            message: 'Domain importing presentation',
          ),
          Finding(
            ruleId: 'empty_catch',
            ruleName: 'Empty Catch Block',
            severity: Severity.warning,
            filePath: tempFile.path,
            line: 8,
            message: 'Silent catch block',
          ),
          Finding(
            ruleId: 'unchecked_boundary',
            ruleName: 'Unchecked Boundary',
            severity: Severity.error,
            filePath: tempFile.path,
            line: 4,
            message: 'Controller catching raw Exception',
          ),
        ],
        lineCount: 30,
        analysisTimeMs: 10,
      );

      final report = ProjectReport(
        projectPath: tempDir.path,
        fileReports: [fileReport],
        totalAnalysisTimeMs: 20,
        analyzedAt: DateTime(2026, 6, 17, 12, 0, 0),
      );

      final output = reporter.format(report);

      // Topological priority order:
      // 1. boundary_violation (Level 1)
      // 2. unchecked_boundary (Level 2)
      // 3. empty_catch (Level 3)
      // 4. cognitive_complexity (Level 4)
      final posBoundary = output.indexOf('Remedio #1: Boundary Violation');
      final posUnchecked = output.indexOf('Remedio #2: Unchecked Boundary');
      final posEmptyCatch = output.indexOf('Remedio #3: Empty Catch Block');
      final posCognitive = output.indexOf('Remedio #4: Cognitive Complexity');

      expect(posBoundary, isNot(-1));
      expect(posUnchecked, isNot(-1));
      expect(posEmptyCatch, isNot(-1));
      expect(posCognitive, isNot(-1));

      expect(posBoundary < posUnchecked, isTrue);
      expect(posUnchecked < posEmptyCatch, isTrue);
      expect(posEmptyCatch < posCognitive, isTrue);
    });

    test('generates complete 3-phase template with enclosing method scope', () {
      const enclosingMethod = '''
Future<void> fetchUser() async {
  try {
    await api.call();
  } catch (e) {}
}''';

      final finding = Finding(
        ruleId: 'empty_catch',
        ruleName: 'Empty or Silent Catch Block',
        severity: Severity.warning,
        filePath: tempFile.path,
        line: 4,
        message: 'Silent catch block',
        evidence: {
          'enclosing_declaration': enclosingMethod,
          'enclosing_name': 'fetchUser',
          'clause': 'catch (e) {}',
        },
      );

      final prompt = PromptReporter.buildPromptForFinding(
        finding,
        tempDir.path,
      );

      // Verify 3 Phases
      expect(prompt, contains('[1. CONTEXTO AISLADO]'));
      expect(prompt, contains('Ámbito contenedor (fetchUser):'));
      expect(prompt, contains('Future<void> fetchUser() async {'));

      expect(
        prompt,
        contains('[2. RESTRICCIONES NEGATIVAS (PROHIBICIONES ESTRICTAS)]'),
      );
      expect(
        prompt,
        contains('NO dejes el bloque catch vacío ni tragues silenciosamente'),
      );
      expect(
        prompt,
        contains('NO agregues dependencias externas no declaradas'),
      );

      expect(prompt, contains('[3. CONTRATO DE SOLUCIÓN (vetro_core)]'));
      expect(
        prompt,
        contains(
          'Utiliza Result.guard() o Result.guardAsync() de package:vetro_core/vetro_core.dart',
        ),
      );

      // Verify strict non-conversational delivery rule
      expect(prompt, contains('Reglas estrictas de entrega:'));
      expect(
        prompt,
        contains(
          'Devuelve únicamente el fragmento de código refactorizado y limpio.',
        ),
      );
      expect(
        prompt,
        contains(
          'Sin explicaciones conversacionales, comentarios superfluos ni saludos.',
        ),
      );
    });
  });
}
