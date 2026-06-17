import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
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
      expect(output, contains('No se encontraron hallazgos de deuda. ¡El código está impecable!'));
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
      expect(output, contains('Function has cognitive complexity of 12 (threshold is 10)'));
      
      // Code Context snippet checking
      expect(output, contains('### Código de Contexto:'));
      expect(output, contains('👉 7:   print(\'Line 6\'); // This is line 7'));
      expect(output, contains('   2:   print(\'Line 1\');')); // context lines
      
      // Evidence checking
      expect(output, contains('### Evidencia Métrica:'));
      expect(output, contains('- **complexity**: `12`'));
      expect(output, contains('- **threshold**: `10`'));

      // Prompt / Instructions checking
      expect(output, contains('### 📋 Prompt / Instrucciones de Refactorización para la IA:'));
      expect(output, contains('Actúa como un ingeniero de software experto en refactorización de código limpio.'));
      expect(output, contains('Reduce el anidamiento de control. Utiliza guardias y retornos tempranos (early returns).'));
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
      expect(output, contains('Añade un comentario de docstring descriptivo que responda a: ¿por qué se tomó esta decisión de diseño'));
    });
  });
}
